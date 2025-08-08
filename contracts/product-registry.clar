;; product-registry.clar
;; Clarity v2
;; Manages minting of unique product NFTs with manufacturing metadata
;; Restricts minting to authorized manufacturers
;; Tracks product metadata immutably for supply chain transparency

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-ALREADY-MINTED u101)
(define-constant ERR-INVALID-METADATA u102)
(define-constant ERR-ZERO-ADDRESS u103)
(define-constant ERR-NOT-MANUFACTURER u104)
(define-constant ERR-PAUSED u105)
(define-constant ERR-INVALID-PRODUCT-ID u106)

;; Contract state
(define-data-var admin principal tx-sender)
(define-data-var paused bool false)
(define-data-var last-product-id uint u0)

;; Authorized manufacturers
(define-map manufacturers principal bool)

;; Product NFT data
(define-non-fungible-token product-nft uint)

;; Product metadata storage
(define-map product-metadata
  { product-id: uint }
  {
    batch-id: (string-ascii 64),
    manufacturing-date: uint,
    origin: (string-ascii 128),
    manufacturer: principal,
    mint-timestamp: uint
  }
)

;; Manufacturer metadata
(define-map manufacturer-info
  { manufacturer: principal }
  {
    name: (string-ascii 128),
    registration-timestamp: uint
  }
)

;; Private helper: Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Private helper: Ensure contract is not paused
(define-private (ensure-not-paused)
  (asserts! (not (var-get paused)) (err ERR-PAUSED))
)

;; Private helper: Check if caller is authorized manufacturer
(define-private (is-manufacturer (caller principal))
  (default-to false (map-get? manufacturers caller))
)

;; Private helper: Validate metadata
(define-private (validate-metadata (batch-id (string-ascii 64)) (origin (string-ascii 128)))
  (and
    (> (len batch-id) u0)
    (<= (len batch-id) u64)
    (> (len origin) u0)
    (<= (len origin) u128)
  )
)

;; Admin: Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq new-admin 'SP000000000000000000002Q6VF78)) (err ERR-ZERO-ADDRESS))
    (var-set admin new-admin)
    (ok true)
  )
)

;; Admin: Pause/unpause contract
(define-public (set-paused (pause bool))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (var-set paused pause)
    (ok pause)
  )
)

;; Admin: Add manufacturer
(define-public (add-manufacturer (manufacturer principal) (name (string-ascii 128)))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq manufacturer 'SP000000000000000000002Q6VF78)) (err ERR-ZERO-ADDRESS))
    (asserts! (> (len name) u0) (err ERR-INVALID-METADATA))
    (map-set manufacturers manufacturer true)
    (map-set manufacturer-info
      { manufacturer: manufacturer }
      {
        name: name,
        registration-timestamp: block-height
      }
    )
    (ok true)
  )
)

;; Admin: Remove manufacturer
(define-public (remove-manufacturer (manufacturer principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-manufacturer manufacturer) (err ERR-NOT-MANUFACTURER))
    (map-delete manufacturers manufacturer)
    (map-delete manufacturer-info { manufacturer: manufacturer })
    (ok true)
  )
)

;; Manufacturer: Mint product NFT
(define-public (mint-product
  (batch-id (string-ascii 64))
  (manufacturing-date uint)
  (origin (string-ascii 128))
)
  (begin
    (ensure-not-paused)
    (asserts! (is-manufacturer tx-sender) (err ERR-NOT-MANUFACTURER))
    (asserts! (validate-metadata batch-id origin) (err ERR-INVALID-METADATA))
    (let
      (
        (product-id (+ (var-get last-product-id) u1))
      )
      (asserts! (is-none (nft-get-owner? product-nft product-id)) (err ERR-ALREADY-MINTED))
      (try! (nft-mint? product-nft product-id tx-sender))
      (map-set product-metadata
        { product-id: product-id }
        {
          batch-id: batch-id,
          manufacturing-date: manufacturing-date,
          origin: origin,
          manufacturer: tx-sender,
          mint-timestamp: block-height
        }
      )
      (var-set last-product-id product-id)
      (ok product-id)
    )
  )
)

;; Read-only: Get product metadata
(define-read-only (get-product-metadata (product-id uint))
  (ok (map-get? product-metadata { product-id: product-id }))
)

;; Read-only: Get product owner
(define-read-only (get-product-owner (product-id uint))
  (ok (nft-get-owner? product-nft product-id))
)

;; Read-only: Get manufacturer info
(define-read-only (get-manufacturer-info (manufacturer principal))
  (ok (map-get? manufacturer-info { manufacturer: manufacturer }))
)

;; Read-only: Check if manufacturer is authorized
(define-read-only (is-authorized-manufacturer (manufacturer principal))
  (ok (is-manufacturer manufacturer))
)

;; Read-only: Get last product ID
(define-read-only (get-last-id)
  (ok (var-get last-product-id))
)

;; Read-only: Get admin
(define-read-only (get-admin)
  (ok (var-get admin))
)

;; Read-only: Check if paused
(define-read-only (is-paused)
  (ok (var-get paused))
)