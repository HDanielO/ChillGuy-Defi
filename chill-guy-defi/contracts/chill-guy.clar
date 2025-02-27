;; title: chillguy-token
;; version: 1.0.0
;; summary: A fungible token for rewarding donations and fitness activities
;; description: ChillGuy Token (CfT) is a community-focused token that incentivizes charitable giving and fitness goals

;; ChillGuy Token - Minting and Distribution Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-insufficient-tokens (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-invalid-params (err u104))
(define-constant err-no-vesting-schedule (err u105))

;; Token definitions
(define-fungible-token chillguy-token)
(define-data-var token-name (string-ascii 32) "ChillGuy Token")
(define-data-var token-symbol (string-ascii 10) "CfT")
(define-data-var token-decimals uint u6)
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var token-description (string-utf8 256) "Rewarding fitness and charitable giving on Stacks")

;; Cap on total supply
(define-data-var token-cap uint u1000000000000) ;; 1 billion tokens with 6 decimals

;; Data maps
(define-map approved-minters principal bool)

;; Vesting functionality for long-term incentives
(define-map token-vesting
  { user: principal }
  { 
    total-amount: uint,
    released-amount: uint,
    vesting-start: uint,
    vesting-duration: uint
  }
)

;; Token freeze mechanism to prevent transfers in emergency
(define-data-var token-frozen bool false)

;; Private functions
(define-private (is-approved-minter (account principal))
  (default-to false (map-get? approved-minters account))
)

;; Check if token operations are allowed
(define-private (check-if-allowed)
  (asserts! (not (var-get token-frozen)) err-not-authorized)
  (ok true)
)

;; Public functions

;; Mint new tokens (only by approved minters)
(define-public (mint (amount uint) (recipient principal))
  (begin
    (try! (check-if-allowed))
    (asserts! (is-approved-minter tx-sender) err-not-authorized)
    (asserts! (<= (+ (ft-get-supply chillguy-token) amount) (var-get token-cap)) err-insufficient-tokens)
    (ft-mint? chillguy-token amount recipient)
  )
)

;; Distribute tokens for donations
(define-public (distribute-for-donation (amount uint) (donor principal))
  (begin
    (try! (check-if-allowed))
    (asserts! (is-approved-minter tx-sender) err-not-authorized)
    (asserts! (> amount u0) err-invalid-amount)
    (ft-mint? chillguy-token amount donor)
  )
)

;; Distribute tokens for fitness challenges
(define-public (distribute-for-fitness (amount uint) (user principal))
  (begin
    (try! (check-if-allowed))
    (asserts! (is-approved-minter tx-sender) err-not-authorized)
    (asserts! (> amount u0) err-invalid-amount)
    (ft-mint? chillguy-token amount user)
  )
)

;; Transfer tokens
(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (begin
    (try! (check-if-allowed))
    (asserts! (is-eq tx-sender sender) err-not-authorized)
    (ft-transfer? chillguy-token amount sender recipient)
  )
)

;; Bulk transfer to multiple recipients
(define-public (bulk-transfer (amount-per-recipient uint) (sender principal) (recipients (list 20 principal)))
  (begin
    (try! (check-if-allowed))
    (asserts! (is-eq tx-sender sender) err-not-authorized)
    (asserts! (> amount-per-recipient u0) err-invalid-amount)
    (asserts! (> (len recipients) u0) err-invalid-params)
    (ok (map transfer-to-recipient recipients))
  )
)

(define-private (transfer-to-recipient (recipient principal))
  (ft-transfer? chillguy-token amount-per-recipient tx-sender recipient)
)

;; Vesting Functions

;; Create a vesting schedule for a recipient
(define-public (create-vesting-schedule (recipient principal) (amount uint) (duration uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> duration u0) err-invalid-params)
    ;; Reserve the tokens from the total supply
    (try! (ft-mint? chillguy-token amount (as-contract tx-sender)))
    (ok (map-set token-vesting
      { user: recipient }
      { 
        total-amount: amount,
        released-amount: u0,
        vesting-start: block-height,
        vesting-duration: duration
      }
    ))
  )
)

;; Release vested tokens based on time elapsed
(define-public (release-vested-tokens)
  (let
    (
      (vesting-data (unwrap! (map-get? token-vesting { user: tx-sender }) err-no-vesting-schedule))
      (total-amount (get total-amount vesting-data))
      (released-amount (get released-amount vesting-data))
      (vesting-start (get vesting-start vesting-data))
      (vesting-duration (get vesting-duration vesting-data))
      (elapsed (- block-height vesting-start))
      (releasable-amount (if (>= elapsed vesting-duration)
                            (- total-amount released-amount)
                            (- (/ (* total-amount elapsed) vesting-duration) released-amount)))
    )
    (asserts! (> releasable-amount u0) err-insufficient-tokens)
    (try! (as-contract (ft-transfer? chillguy-token releasable-amount (as-contract tx-sender) tx-sender)))
    (ok (map-set token-vesting
      { user: tx-sender }
      (merge vesting-data { released-amount: (+ released-amount releasable-amount) })
    ))
  )
)

;; Administrative functions

;; Add an approved minter
(define-public (add-approved-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set approved-minters minter true))
  )
)

;; Remove an approved minter
(define-public (remove-approved-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-delete approved-minters minter))
  )
)

;; Update token URI
(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set token-uri new-uri))
  )
)

;; Update token description
(define-public (set-token-description (new-description (string-utf8 256)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set token-description new-description))
  )
)

;; Emergency freeze/unfreeze functionality
(define-public (set-frozen-state (frozen bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set token-frozen frozen))
  )
)

;; Read-only functions

;; Get token name
(define-read-only (get-name)
  (ok (var-get token-name))
)

;; Get token symbol
(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

;; Get number of decimals
(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

;; Get token URI
(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

;; Get token description
(define-read-only (get-token-description)
  (ok (var-get token-description))
)

;; Get balance of an account
(define-read-only (get-balance (account principal))
  (ok (ft-get-balance chillguy-token account))
)

;; Get total supply
(define-read-only (get-total-supply)
  (ok (ft-get-supply chillguy-token))
)

;; Check if an account is an approved minter
(define-read-only (is-minter (account principal))
  (ok (is-approved-minter account))
)

;; Get vesting schedule details for a user
(define-read-only (get-vesting-schedule (user principal))
  (ok (map-get? token-vesting { user: user }))
)

;; Get current frozen state
(define-read-only (get-frozen-state)
  (ok (var-get token-frozen))
)

;; SIP-010 compliance functions

;; Transfer token on behalf of the sender
(define-public (transfer-from (amount uint) (sender principal) (recipient principal))
  (begin
    (try! (check-if-allowed))
    ;; Implement proper allowance mechanism for SIP-010 compliance
    (ft-transfer? chillguy-token amount sender recipient)
  )
)