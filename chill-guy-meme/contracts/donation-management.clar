;; Chill Guy Management Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-invalid-campaign (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-goal-not-met (err u104))

;; Define the token contract
(define-trait token-trait
  (
    (transfer (uint principal principal) (response bool uint))
    (get-balance (principal) (response uint uint))
  )
)

;; Data variables
(define-data-var next-campaign-id uint u1)

;; Data maps
(define-map campaigns
  { campaign-id: uint }
  {
    name: (string-ascii 100),
    description: (string-utf8 500),
    creator: principal,
    goal: uint,
    raised: uint,
    active: bool
  }
)

(define-map donations
  { campaign-id: uint, donor: principal }
  { amount: uint }
)

;; Private functions
(define-private (transfer-tokens (token <token-trait>) (amount uint) (sender principal) (recipient principal))
  (contract-call? token transfer amount sender recipient)
)

;; Public functions

;; Create a new fundraising campaign
(define-public (create-campaign (name (string-ascii 100)) (description (string-utf8 500)) (goal uint))
  (let
    (
      (campaign-id (var-get next-campaign-id))
    )
    (asserts! (> goal u0) err-invalid-amount)
    (map-set campaigns
      { campaign-id: campaign-id }
      {
        name: name,
        description: description,
        creator: tx-sender,
        goal: goal,
        raised: u0,
        active: true
      }
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
      (current-donation (default-to { amount: u0 } (map-get? donations { campaign-id: campaign-id, donor: tx-sender })))
    )
    (asserts! (get active campaign) err-invalid-campaign)
    (asserts! (> amount u0) err-invalid-amount)
    (try! (transfer-tokens token amount tx-sender (as-contract tx-sender)))
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { raised: (+ (get raised campaign) amount) })
    )
    (map-set donations
      { campaign-id: campaign-id, donor: tx-sender }
      { amount: (+ (get amount current-donation) amount) }
    )
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

;; Read-only functions

;; Get campaign details
(define-read-only (get-campaign-details (campaign-id uint))
  (map-get? campaigns { campaign-id: campaign-id })
)

;; Get donation amount for a specific donor and campaign
(define-read-only (get-donation-amount (campaign-id uint) (donor principal))
  (default-to { amount: u0 } (map-get? donations { campaign-id: campaign-id, donor: donor }))
)

;; Get total number of campaigns
(define-read-only (get-total-campaigns)
  (- (var-get next-campaign-id) u1)
)

;; Helper function to get campaign details
(define-read-only (get-campaign (id uint))
  (map-get? campaigns { campaign-id: id })
)