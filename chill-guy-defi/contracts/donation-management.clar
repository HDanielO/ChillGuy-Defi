;; Chill Guy Management Contract
;; version: 1.0.0
;; summary: A contract for managing fundraising campaigns and donations
;; description: This contract enables users to create campaigns, receive donations in ChillGuy Tokens, and withdraw funds when goals are met

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-invalid-campaign (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-goal-not-met (err u104))
(define-constant err-campaign-expired (err u105))
(define-constant err-milestone-not-met (err u106))
(define-constant err-invalid-milestone (err u107))
(define-constant err-invalid-category (err u108))
(define-constant err-campaign-inactive (err u109))

;; Define the token contract
(define-trait token-trait
  (
    (transfer (uint principal principal) (response bool uint))
    (get-balance (principal) (response uint uint))
  )
)

;; Data variables
(define-data-var next-campaign-id uint u1)
(define-data-var next-category-id uint u1)
(define-data-var platform-fee-percentage uint u25) ;; 2.5% fee (scaled by 1000)
(define-data-var total-platform-fees uint u0)

;; Data maps
(define-map campaigns
  { campaign-id: uint }
  {
    name: (string-ascii 100),
    description: (string-utf8 500),
    creator: principal,
    goal: uint,
    raised: uint,
    active: bool,
    category-id: (optional uint),
    deadline: (optional uint),
    featured: bool,
    date-created: uint
  }
)

(define-map donations
  { campaign-id: uint, donor: principal }
  { amount: uint, donations-count: uint, last-donation-height: uint }
)

;; Campaign milestones for staged fundraising
(define-map campaign-milestones
  { campaign-id: uint, milestone-id: uint }
  {
    title: (string-ascii 100),
    description: (string-utf8 300),
    amount-needed: uint,
    completed: bool
  }
)

;; Campaign updates for progress reporting
(define-map campaign-updates
  { campaign-id: uint, update-id: uint }
  {
    title: (string-ascii 100),
    content: (string-utf8 1000),
    timestamp: uint
  }
)

;; Next update ID tracker
(define-map campaign-update-counter
  { campaign-id: uint }
  { update-count: uint }
)

;; Campaign categories
(define-map campaign-categories
  { category-id: uint }
  { name: (string-ascii 50), description: (string-utf8 200) }
)

;; Campaign statistics
(define-map campaign-stats
  { campaign-id: uint }
  {
    total-donors: uint,
    average-donation: uint,
    largest-donation: uint,
    largest-donor: (optional principal)
  }
)

;; Private functions
(define-private (transfer-tokens (token <token-trait>) (amount uint) (sender principal) (recipient principal))
  (contract-call? token transfer amount sender recipient)
)

(define-private (calculate-fee (amount uint))
  (/ (* amount (var-get platform-fee-percentage)) u1000)
)

(define-private (update-campaign-stats (campaign-id uint) (donor principal) (amount uint))
  (let
    (
      (current-stats (default-to 
        { total-donors: u0, average-donation: u0, largest-donation: u0, largest-donor: none }
        (map-get? campaign-stats { campaign-id: campaign-id })))
      (current-donation (default-to { amount: u0, donations-count: u0, last-donation-height: u0 } 
        (map-get? donations { campaign-id: campaign-id, donor: donor })))
      (is-new-donor (is-eq (get donations-count current-donation) u0))
      (new-total-donors (if is-new-donor (+ (get total-donors current-stats) u1) (get total-donors current-stats)))
      (new-largest-donation (if (> amount (get largest-donation current-stats))
                               amount
                               (get largest-donation current-stats)))
      (new-largest-donor (if (> amount (get largest-donation current-stats))
                            (some donor)
                            (get largest-donor current-stats)))
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-invalid-campaign))
      (total-raised (get raised campaign))
      (new-average (if (is-eq new-total-donors u0)
                      u0
                      (/ total-raised new-total-donors)))
    )
    (map-set campaign-stats
      { campaign-id: campaign-id }
      {
        total-donors: new-total-donors,
        average-donation: new-average,
        largest-donation: new-largest-donation,
        largest-donor: new-largest-donor
      }
    )
  )
)

;; Public functions

;; Create a new fundraising campaign
(define-public (create-campaign (name (string-ascii 100)) (description (string-utf8 500)) (goal uint)
                              (category-id (optional uint)))
  (let
    (
      (campaign-id (var-get next-campaign-id))
    )
    (asserts! (> goal u0) err-invalid-amount)
    ;; Verify category exists if specified
    (if (is-some category-id)
      (asserts! (is-some (map-get? campaign-categories { category-id: (unwrap-panic category-id) })) err-invalid-category)
      true
    )
    (map-set campaigns
      { campaign-id: campaign-id }
      {
        name: name,
        description: description,
        creator: tx-sender,
        goal: goal,
        raised: u0,
        active: true,
        category-id: category-id,
        deadline: none,
        featured: false,
        date-created: block-height
      }
    )
    ;; Initialize campaign stats
    (map-set campaign-stats
      { campaign-id: campaign-id }
      {
        total-donors: u0,
        average-donation: u0,
        largest-donation: u0,
        largest-donor: none
      }
    )
    ;; Initialize update counter
    (map-set campaign-update-counter
      { campaign-id: campaign-id }
      { update-count: u0 }
    )
    (var-set next-campaign-id (+ campaign-id u1))
    (ok campaign-id)
  )
)

;; Donate tokens to a campaign
(define-public (donate-to-campaign (token <token-trait>) (campaign-id uint) (amount uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-invalid-campaign))
      (current-donation (default-to 
        { amount: u0, donations-count: u0, last-donation-height: u0 } 
        (map-get? donations { campaign-id: campaign-id, donor: tx-sender })))
      (fee (calculate-fee amount))
      (campaign-amount (- amount fee))
    )
    (asserts! (get active campaign) err-campaign-inactive)
    (asserts! (> amount u0) err-invalid-amount)
    
    ;; Check if campaign has deadline and if it's expired
    (if (is-some (get deadline campaign))
      (asserts! (<= block-height (unwrap-panic (get deadline campaign))) err-campaign-expired)
      true
    )
    
    ;; Transfer tokens to the contract
    (try! (transfer-tokens token amount tx-sender (as-contract tx-sender)))
    
    ;; Update campaign funds raised
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { raised: (+ (get raised campaign) campaign-amount) })
    )
    
    ;; Update donor's donation record
    (map-set donations
      { campaign-id: campaign-id, donor: tx-sender }
      { 
        amount: (+ (get amount current-donation) amount),
        donations-count: (+ (get donations-count current-donation) u1),
        last-donation-height: block-height
      }
    )
    
    ;; Update platform fees
    (var-set total-platform-fees (+ (var-get total-platform-fees) fee))
    
    ;; Update campaign statistics
    (update-campaign-stats campaign-id tx-sender amount)
    
    ;; Check if any milestones are completed
    (try! (check-milestone-completion campaign-id))
    
    (ok true)
  )
)

;; Check and update milestone completion status
(define-private (check-milestone-completion (campaign-id uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-invalid-campaign))
      (raised (get raised campaign))
    )
    ;; Logic to iterate through milestones and update completion status
    ;; This is simplified since we can't iterate through maps in Clarity
    (ok true)
  )
)

;; Withdraw funds from a campaign (only by campaign creator and if goal is met)
(define-public (withdraw-campaign-funds (token <token-trait>) (campaign-id uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-invalid-campaign))
    )
    (asserts! (is-eq (get creator campaign) tx-sender) err-not-authorized)
    (asserts! (>= (get raised campaign) (get goal campaign)) err-goal-not-met)
    (try! (as-contract (transfer-tokens token (get raised campaign) tx-sender (get creator campaign))))
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { active: false })
    )
    (ok true)
  )
)

;; Withdraw funds for a specific milestone
(define-public (withdraw-milestone-funds (token <token-trait>) (campaign-id uint) (milestone-id uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-invalid-campaign))
      (milestone (unwrap! (map-get? campaign-milestones { campaign-id: campaign-id, milestone-id: milestone-id }) err-invalid-milestone))
    )
    (asserts! (is-eq (get creator campaign) tx-sender) err-not-authorized)
    (asserts! (get completed milestone) err-milestone-not-met)
    ;; Logic to transfer funds for this milestone
    (ok true)
  )
)

;; Add a milestone to a campaign
(define-public (add-campaign-milestone (campaign-id uint) (title (string-ascii 100)) 
                                     (description (string-utf8 300)) (amount-needed uint) (milestone-id uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-invalid-campaign))
    )
    (asserts! (is-eq (get creator campaign) tx-sender) err-not-authorized)
    (asserts! (> amount-needed u0) err-invalid-amount)
    (asserts! (<= amount-needed (get goal campaign)) err-invalid-amount)
    
    (ok (map-set campaign-milestones
      { campaign-id: campaign-id, milestone-id: milestone-id }
      {
        title: title,
        description: description,
        amount-needed: amount-needed,
        completed: false
      }
    ))
  )
)

;; Post an update to a campaign
(define-public (post-campaign-update (campaign-id uint) (title (string-ascii 100)) (content (string-utf8 1000)))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-invalid-campaign))
      (counter (default-to { update-count: u0 } (map-get? campaign-update-counter { campaign-id: campaign-id })))
      (next-update-id (get update-count counter))
    )
    (asserts! (is-eq (get creator campaign) tx-sender) err-not-authorized)
    
    (map-set campaign-updates
      { campaign-id: campaign-id, update-id: next-update-id }
      {
        title: title,
        content: content,
        timestamp: block-height
      }
    )
    
    (map-set campaign-update-counter
      { campaign-id: campaign-id }
      { update-count: (+ next-update-id u1) }
    )
    
    (ok next-update-id)
  )
)

;; Set a deadline for a campaign
(define-public (set-campaign-deadline (campaign-id uint) (deadline-height uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-invalid-campaign))
    )
    (asserts! (is-eq (get creator campaign) tx-sender) err-not-authorized)
    (asserts! (> deadline-height block-height) err-invalid-amount)
    
    (ok (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { deadline: (some deadline-height) })
    ))
  )
)

;; Administrative functions

;; Update campaign status (only by contract owner)
(define-public (update-campaign-status (campaign-id uint) (active bool))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-invalid-campaign))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { active: active })
    ))
  )
)

;; Create a new campaign category
(define-public (create-category (name (string-ascii 50)) (description (string-utf8 200)))
  (let
    (
      (category-id (var-get next-category-id))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (map-set campaign-categories
      { category-id: category-id }
      { name: name, description: description }
    )
    
    (var-set next-category-id (+ category-id u1))
    (ok category-id)
  )
)

;; Feature a campaign (special visibility)
(define-public (feature-campaign (campaign-id uint) (featured bool))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-invalid-campaign))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (ok (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { featured: featured })
    ))
  )
)

;; Update platform fee percentage
(define-public (set-platform-fee (new-fee-percentage uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee-percentage u100) err-invalid-amount) ;; Max 10% (100/1000)
    
    (ok (var-set platform-fee-percentage new-fee-percentage))
  )
)

;; Withdraw platform fees
(define-public (withdraw-platform-fees (token <token-trait>) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> (var-get total-platform-fees) u0) err-invalid-amount)
    
    (let
      (
        (fees (var-get total-platform-fees))
      )
      (try! (as-contract (transfer-tokens token fees tx-sender recipient)))
      (var-set total-platform-fees u0)
      (ok fees)
    )
  )
)

;; Read-only functions

;; Get campaign details
(define-read-only (get-campaign-details (campaign-id uint))
  (map-get? campaigns { campaign-id: campaign-id })
)

;; Get donation amount for a specific donor and campaign
(define-read-only (get-donation-amount (campaign-id uint) (donor principal))
  (default-to { amount: u0, donations-count: u0, last-donation-height: u0 } 
    (map-get? donations { campaign-id: campaign-id, donor: donor }))
)

;; Get total number of campaigns
(define-read-only (get-total-campaigns)
  (- (var-get next-campaign-id) u1)
)

;; Get campaign milestone details
(define-read-only (get-campaign-milestone (campaign-id uint) (milestone-id uint))
  (map-get? campaign-milestones { campaign-id: campaign-id, milestone-id: milestone-id })
)

;; Get campaign update
(define-read-only (get-campaign-update (campaign-id uint) (update-id uint))
  (map-get? campaign-updates { campaign-id: campaign-id, update-id: update-id })
)

;; Get total updates for a campaign
(define-read-only (get-update-count (campaign-id uint))
  (get update-count (default-to { update-count: u0 } 
    (map-get? campaign-update-counter { campaign-id: campaign-id })))
)

;; Get category details
(define-read-only (get-category (category-id uint))
  (map-get? campaign-categories { category-id: category-id })
)

;; Get campaign stats
(define-read-only (get-campaign-statistics (campaign-id uint))
  (map-get? campaign-stats { campaign-id: campaign-id })
)

;; Get platform fee percentage
(define-read-only (get-platform-fee)
  (var-get platform-fee-percentage)
)

;; Get total platform fees collected
(define-read-only (get-total-platform-fees)
  (var-get total-platform-fees)
)

;; Helper function to get campaign details
(define-read-only (get-campaign (id uint))
  (map-get? campaigns { campaign-id: id })
)

;; Get featured campaigns (simplified - in a real implementation you'd need a more complex query mechanism)
(define-read-only (is-campaign-featured (campaign-id uint))
  (get featured (default-to 
    { featured: false } 
    (map-get? campaigns { campaign-id: campaign-id })))
)

;; Get campaigns by category (simplified - in a real implementation you'd need indexing)
(define-read-only (is-campaign-in-category (campaign-id uint) (category-id uint))
  (is-eq (some category-id) (get category-id (default-to 
    { category-id: none } 
    (map-get? campaigns { campaign-id: campaign-id }))))
)