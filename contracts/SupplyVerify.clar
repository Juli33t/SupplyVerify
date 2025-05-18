;; SupplyVerify - Supply chain verification platform with on-chain product tracking
;; Manufacturers earn tokens based on verification and quality ratings

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_INPUT (err u103))
(define-constant ERR_ALREADY_VERIFIED (err u104))
(define-constant ERR_ALREADY_RATED (err u105))
(define-constant ERR_SELF_RATING (err u106))
(define-constant ERR_EMPTY_STRING (err u107))
(define-constant ERR_INVALID_RATING (err u108))
(define-constant ERR_INVALID_PRODUCT_ID (err u109))
(define-constant ERR_EMPTY_HASH (err u110))

;; Constants
(define-constant MAX_RATING u5)
(define-constant SCAN_REWARD u10)
(define-constant QUALITY_REWARD u20)
(define-constant VERIFICATION_REWARD u50)

;; Data maps
(define-map entities
  { entity-id: principal }
  { name: (string-ascii 50), reputation: uint, tokens: uint, certified: bool }
)

(define-map products
  { product-id: uint }
  { 
    manufacturer: principal, 
    description: (string-ascii 500), 
    product-hash: (buff 32),
    timestamp: uint, 
    verified: bool,
    verification-count: uint,
    scan-count: uint,
    quality-rating: uint,
    rating-count: uint
  }
)

(define-map product-verifications
  { product-id: uint, verifier: principal }
  { verified: bool }
)

(define-map product-scans
  { product-id: uint, entity: principal }
  { scanned: bool, scan-location: (string-ascii 100) }
)

(define-map product-ratings
  { product-id: uint, rater: principal }
  { rating: uint }
)

;; Variables
(define-data-var next-product-id uint u1)
(define-data-var action-counter uint u0)

;; Helper functions
(define-private (is-valid-product-id (product-id uint))
  (< product-id (var-get next-product-id))
)

;; Entity functions
(define-public (register-entity (name (string-ascii 50)))
  (let ((caller tx-sender))
    ;; Validate name is not empty
    (asserts! (> (len name) u0) ERR_EMPTY_STRING)
    ;; Check if entity already exists
    (asserts! (is-none (map-get? entities {entity-id: caller})) ERR_ALREADY_EXISTS)
    ;; Register entity
    (ok (map-set entities 
      {entity-id: caller} 
      {name: name, reputation: u0, tokens: u100, certified: false}))
  )
)

(define-public (update-entity-name (name (string-ascii 50)))
  (let ((caller tx-sender))
    ;; Validate name is not empty
    (asserts! (> (len name) u0) ERR_EMPTY_STRING)
    ;; Check if entity exists
    (asserts! (is-some (map-get? entities {entity-id: caller})) ERR_NOT_FOUND)
    ;; Update name
    (ok (map-set entities 
      {entity-id: caller} 
      (merge (unwrap! (map-get? entities {entity-id: caller}) ERR_NOT_FOUND)
             {name: name})))
  )
)

;; Product functions
(define-public (register-product (description (string-ascii 500)) (product-hash (buff 32)))
  (let ((caller tx-sender)
        (product-id (var-get next-product-id)))
    ;; Validate description is not empty
    (asserts! (> (len description) u0) ERR_EMPTY_STRING)
    ;; Validate product-hash is not empty
    (asserts! (> (len product-hash) u0) ERR_EMPTY_HASH)
    ;; Check if entity exists
    (asserts! (is-some (map-get? entities {entity-id: caller})) ERR_NOT_FOUND)
    ;; Increment action counter
    (var-set action-counter (+ (var-get action-counter) u1))
    
    ;; Create product with validated data
    (map-set products 
      {product-id: product-id} 
      { 
        manufacturer: caller, 
        description: description, 
        product-hash: product-hash,
        timestamp: (var-get action-counter), 
        verified: false,
        verification-count: u0,
        scan-count: u0,
        quality-rating: u0,
        rating-count: u0
      })
    ;; Increment product ID
    (var-set next-product-id (+ product-id u1))
    (ok product-id)
  )
)

(define-public (verify-product (product-id uint))
  (let ((caller tx-sender))
    ;; Validate product-id
    (asserts! (is-valid-product-id product-id) ERR_INVALID_PRODUCT_ID)
    ;; Check if entity exists
    (asserts! (is-some (map-get? entities {entity-id: caller})) ERR_NOT_FOUND)
    ;; Check if product exists
    (asserts! (is-some (map-get? products {product-id: product-id})) ERR_NOT_FOUND)
    
    ;; Get product data
    (let ((product (unwrap! (map-get? products {product-id: product-id}) ERR_NOT_FOUND)))
      ;; Check if entity is not the manufacturer
      (asserts! (not (is-eq caller (get manufacturer product))) ERR_SELF_RATING)
      ;; Check if entity has not already verified this product
      (asserts! (is-none (map-get? product-verifications {product-id: product-id, verifier: caller})) ERR_ALREADY_VERIFIED)
      
      ;; Record verification with validated product-id
      (map-set product-verifications 
        {product-id: product-id, verifier: caller} 
        {verified: true})
      
      ;; Update product verification count
      (let ((new-verification-count (+ (get verification-count product) u1))
            (manufacturer-entity (unwrap! (map-get? entities {entity-id: (get manufacturer product)}) ERR_NOT_FOUND))
            (verifier-entity (unwrap! (map-get? entities {entity-id: caller}) ERR_NOT_FOUND)))
        
        ;; Update product data with validated product-id
        (map-set products 
          {product-id: product-id} 
          (merge product {
            verification-count: new-verification-count,
            verified: (>= new-verification-count u3)
          }))
        
        ;; Reward verifier with tokens
        (map-set entities 
          {entity-id: caller} 
          (merge verifier-entity {
            tokens: (+ (get tokens verifier-entity) u5),
            reputation: (+ (get reputation verifier-entity) u1)
          }))
        
        ;; If product becomes verified (3+ verifications), reward manufacturer
        (if (and (>= new-verification-count u3) (not (get verified product)))
          (map-set entities 
            {entity-id: (get manufacturer product)} 
            (merge manufacturer-entity {
              tokens: (+ (get tokens manufacturer-entity) VERIFICATION_REWARD),
              reputation: (+ (get reputation manufacturer-entity) u10)
            }))
          true)
        
        (ok new-verification-count)
      )
    )
  )
)

(define-public (scan-product (product-id uint) (scan-location (string-ascii 100)))
  (let ((caller tx-sender))
    ;; Validate product-id
    (asserts! (is-valid-product-id product-id) ERR_INVALID_PRODUCT_ID)
    ;; Validate scan location is not empty
    (asserts! (> (len scan-location) u0) ERR_EMPTY_STRING)
    ;; Check if entity exists
    (asserts! (is-some (map-get? entities {entity-id: caller})) ERR_NOT_FOUND)
    ;; Check if product exists
    (asserts! (is-some (map-get? products {product-id: product-id})) ERR_NOT_FOUND)
    
    ;; Get product data
    (let ((product (unwrap! (map-get? products {product-id: product-id}) ERR_NOT_FOUND)))
      ;; Check if entity has not already scanned this product
      (asserts! (is-none (map-get? product-scans {product-id: product-id, entity: caller})) ERR_ALREADY_EXISTS)
      
      ;; Record scan with validated product-id
      (map-set product-scans 
        {product-id: product-id, entity: caller} 
        {scanned: true, scan-location: scan-location})
      
      ;; Update product scan count
      (let ((new-scan-count (+ (get scan-count product) u1))
            (manufacturer-entity (unwrap! (map-get? entities {entity-id: (get manufacturer product)}) ERR_NOT_FOUND)))
        
        ;; Update product data with validated product-id
        (map-set products 
          {product-id: product-id} 
          (merge product {scan-count: new-scan-count}))
        
        ;; Reward manufacturer with tokens for scan
        (map-set entities 
          {entity-id: (get manufacturer product)} 
          (merge manufacturer-entity {
            tokens: (+ (get tokens manufacturer-entity) SCAN_REWARD)
          }))
        
        (ok new-scan-count)
      )
    )
  )
)

(define-public (rate-product-quality (product-id uint) (rating uint))
  (let ((caller tx-sender))
    ;; Validate product-id
    (asserts! (is-valid-product-id product-id) ERR_INVALID_PRODUCT_ID)
    ;; Validate rating (1-5)
    (asserts! (and (>= rating u1) (<= rating MAX_RATING)) ERR_INVALID_RATING)
    ;; Check if entity exists
    (asserts! (is-some (map-get? entities {entity-id: caller})) ERR_NOT_FOUND)
    ;; Check if product exists
    (asserts! (is-some (map-get? products {product-id: product-id})) ERR_NOT_FOUND)
    
    ;; Get product data
    (let ((product (unwrap! (map-get? products {product-id: product-id}) ERR_NOT_FOUND)))
      ;; Check if entity is not the manufacturer
      (asserts! (not (is-eq caller (get manufacturer product))) ERR_SELF_RATING)
      ;; Check if entity has not already rated this product
      (asserts! (is-none (map-get? product-ratings {product-id: product-id, rater: caller})) ERR_ALREADY_RATED)
      
      ;; Record rating with validated product-id and rating
      (map-set product-ratings 
        {product-id: product-id, rater: caller} 
        {rating: rating})
      
      ;; Update product rating
      (let ((current-total-rating (* (get quality-rating product) (get rating-count product)))
            (new-rating-count (+ (get rating-count product) u1))
            (new-total-rating (+ current-total-rating rating))
            (new-average-rating (/ new-total-rating new-rating-count))
            (manufacturer-entity (unwrap! (map-get? entities {entity-id: (get manufacturer product)}) ERR_NOT_FOUND))
            (rater-entity (unwrap! (map-get? entities {entity-id: caller}) ERR_NOT_FOUND)))
        
        ;; Update product data with validated product-id
        (map-set products 
          {product-id: product-id} 
          (merge product {
            quality-rating: new-average-rating,
            rating-count: new-rating-count
          }))
        
        ;; Reward rater with tokens
        (map-set entities 
          {entity-id: caller} 
          (merge rater-entity {
            tokens: (+ (get tokens rater-entity) u2),
            reputation: (+ (get reputation rater-entity) u1)
          }))
        
        ;; Reward manufacturer based on rating
        (if (>= rating u4)
          (map-set entities 
            {entity-id: (get manufacturer product)} 
            (merge manufacturer-entity {
              tokens: (+ (get tokens manufacturer-entity) QUALITY_REWARD),
              reputation: (+ (get reputation manufacturer-entity) u5)
            }))
          true)
        
        (ok new-average-rating)
      )
    )
  )
)

;; Read-only functions
(define-read-only (get-entity-info (entity-id principal))
  (map-get? entities {entity-id: entity-id})
)

(define-read-only (get-product (product-id uint))
  (map-get? products {product-id: product-id})
)

(define-read-only (get-product-verification (product-id uint) (verifier principal))
  (map-get? product-verifications {product-id: product-id, verifier: verifier})
)

(define-read-only (get-product-scan (product-id uint) (entity principal))
  (map-get? product-scans {product-id: product-id, entity: entity})
)

(define-read-only (get-product-rating (product-id uint) (rater principal))
  (map-get? product-ratings {product-id: product-id, rater: rater})
)

(define-read-only (get-total-products)
  (- (var-get next-product-id) u1)
)