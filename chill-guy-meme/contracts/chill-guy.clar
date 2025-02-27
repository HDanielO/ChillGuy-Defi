
;; title: chillguy-token
;; version:
;; summary:
;; description:

;; ChillGuy Token - Minting and Distribution Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-insufficient-tokens (err u102))
(define-constant err-invalid-amount (err u103))

;; Token definitions
(define-fungible-token chillguy-token)
(define-data-var token-name (string-ascii 32) "ChillGuy Token")
(define-data-var token-symbol (string-ascii 10) "CfT")
(define-data-var token-decimals uint u6)
(define-data-var token-uri (optional (string-utf8 256)) none)

;; Cap on total supply
(define-data-var token-cap uint u1000000000000) ;; 1 billion tokens with 6 decimals

;; Data maps
(define-map approved-minters principal bool)

;; Private functions
(define-private (is-approved-minter (account principal))
  (default-to false (map-get? approved-minters account))
)

;; Public functions

;; Mint new tokens (only by approved minters)
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-approved-minter tx-sender) err-not-authorized)
    (asserts! (<= (+ (ft-get-supply chillguy-token) amount) (var-get token-cap)) err-insufficient-tokens)
    (ft-mint? chillguy-token amount recipient)
  )
)

;; Distribute tokens for donations
(define-public (distribute-for-donation (amount uint) (donor principal))
  (begin
    (asserts! (is-approved-minter tx-sender) err-not-authorized)
    (asserts! (> amount u0) err-invalid-amount)
    (ft-mint? chillguy-token amount donor)
  )
)

;; Distribute tokens for fitness challenges
(define-public (distribute-for-fitness (amount uint) (user principal))
  (begin
    (asserts! (is-approved-minter tx-sender) err-not-authorized)
    (asserts! (> amount u0) err-invalid-amount)
    (ft-mint? chillguy-token amount user)
  )
)

;; Transfer tokens
(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-authorized)
    (ft-transfer? chillguy-token amount sender recipient)
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