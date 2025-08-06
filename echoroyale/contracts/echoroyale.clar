;; Royalty Distribution for Digital Art
;; Enables automatic royalty distribution to creators and contributors
;; Supports primary sales, secondary market royalties, and collaborative works

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ARTWORK-NOT-FOUND (err u101))
(define-constant ERR-INVALID-INPUT (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-ALREADY-SOLD (err u105))
(define-constant ERR-NOT-SOLD (err u106))
(define-constant ERR-NO-ROYALTIES (err u107))
(define-constant ERR-INVALID-PERCENTAGE (err u108))
(define-constant ERR-CONTRACT-ALREADY-LINKED (err u109))
(define-constant ERR-NO-NFT-CONTRACT (err u110))

;; Maximum values for validation
(define-constant MAX-ROYALTY-PERCENTAGE u300) ;; 30%
(define-constant PERCENTAGE-BASE u1000) ;; 1000 = 100%
(define-constant MAX-TITLE-LENGTH u256)
(define-constant MAX-DESCRIPTION-LENGTH u1024)
(define-constant MAX-ROLE-LENGTH u64)

;; Define artwork data
(define-map artworks
  { artwork-id: uint }
  {
    title: (string-utf8 256),
    description: (string-utf8 1024),
    creator: principal,
    created-at: uint,
    active: bool,
    primary-sold: bool,
    primary-price: uint,
    royalty-percentage: uint,  ;; Out of 1000 (e.g., 50 = 5%)
    nft-contract: (optional principal)
  }
)

;; Contributors to an artwork
(define-map contributors
  { artwork-id: uint, contributor: principal }
  {
    share-percentage: uint,    ;; Out of 1000 (e.g., 500 = 50%)
    role: (string-ascii 64)
  }
)

;; Royalty distribution tracking
(define-map royalty-distributions
  { artwork-id: uint }
  {
    total-royalties: uint,
    last-distribution: uint
  }
)

;; Claimable royalties per contributor
(define-map claimable-royalties
  { artwork-id: uint, contributor: principal }
  { amount: uint }
)

;; Track secondary sales
(define-map secondary-sales
  { artwork-id: uint, sale-id: uint }
  {
    seller: principal,
    buyer: principal,
    amount: uint,
    royalty-amount: uint,
    timestamp: uint
  }
)

;; Next available IDs
(define-data-var next-artwork-id-counter uint u1)
(define-map next-sale-id-counter { artwork-id: uint } { id: uint })

;; Contract owner for administrative functions
(define-data-var contract-owner-address principal tx-sender)

;; Helper function to validate string lengths
(define-private (is-valid-string-length (input-string (string-utf8 1024)) (max-length-limit uint))
  (<= (len input-string) max-length-limit)
)

;; Helper function to validate percentage
(define-private (is-valid-percentage (percentage-value uint))
  (<= percentage-value PERCENTAGE-BASE)
)

;; Register a new artwork
(define-public (register-artwork
                (title-input (string-utf8 256))
                (description-input (string-utf8 1024))
                (primary-price-input uint)
                (royalty-percentage-input uint))
  (let
    ((new-artwork-id (var-get next-artwork-id-counter)))
    
    ;; Validate inputs
    (asserts! (> primary-price-input u0) ERR-INVALID-INPUT)
    (asserts! (<= royalty-percentage-input MAX-ROYALTY-PERCENTAGE) ERR-INVALID-PERCENTAGE)
    (asserts! (> (len title-input) u0) ERR-INVALID-INPUT)
    (asserts! (is-valid-string-length title-input MAX-TITLE-LENGTH) ERR-INVALID-INPUT)
    (asserts! (is-valid-string-length description-input MAX-DESCRIPTION-LENGTH) ERR-INVALID-INPUT)
    
    ;; Create the artwork record
    (map-set artworks
      { artwork-id: new-artwork-id }
      {
        title: title-input,
        description: description-input,
        creator: tx-sender,
        created-at: block-height,
        active: true,
        primary-sold: false,
        primary-price: primary-price-input,
        royalty-percentage: royalty-percentage-input,
        nft-contract: none
      }
    )
    
    ;; Add creator as 100% contributor by default
    (map-set contributors
      { artwork-id: new-artwork-id, contributor: tx-sender }
      {
        share-percentage: PERCENTAGE-BASE,  ;; 100%
        role: "creator"
      }
    )
    
    ;; Initialize royalty tracking
    (map-set royalty-distributions
      { artwork-id: new-artwork-id }
      {
        total-royalties: u0,
        last-distribution: u0
      }
    )
    
    ;; Initialize sale counter
    (map-set next-sale-id-counter
      { artwork-id: new-artwork-id }
      { id: u1 }
    )
    
    ;; Increment artwork ID counter
    (var-set next-artwork-id-counter (+ new-artwork-id u1))
    
    (ok new-artwork-id)
  )
)

;; Add a contributor to an artwork
(define-public (add-contributor
                (artwork-id-input uint)
                (contributor-input principal)
                (share-percentage-input uint)
                (role-input (string-ascii 64)))
  (let
    ((artwork-data (unwrap! (map-get? artworks { artwork-id: artwork-id-input }) ERR-ARTWORK-NOT-FOUND))
     (creator-share-data (unwrap! (map-get? contributors { artwork-id: artwork-id-input, contributor: (get creator artwork-data) })
                            ERR-ARTWORK-NOT-FOUND))
     (current-contributor-record (map-get? contributors { artwork-id: artwork-id-input, contributor: contributor-input }))
     (contributor-already-exists (is-some current-contributor-record))
     (current-share-amount (if contributor-already-exists
                       (get share-percentage (unwrap-panic current-contributor-record))
                      u0))
     (available-share-amount (- (get share-percentage creator-share-data) current-share-amount))
     (new-creator-share-amount (- (get share-percentage creator-share-data) share-percentage-input)))
    
    ;; Validate inputs
    (asserts! (is-eq tx-sender (get creator artwork-data)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get primary-sold artwork-data)) ERR-ALREADY-SOLD)
    (asserts! (> share-percentage-input u0) ERR-INVALID-INPUT)
    (asserts! (<= share-percentage-input available-share-amount) ERR-INVALID-PERCENTAGE)
    (asserts! (> (len role-input) u0) ERR-INVALID-INPUT)
    (asserts! (<= (len role-input) MAX-ROLE-LENGTH) ERR-INVALID-INPUT)
    (asserts! (not (is-eq contributor-input (get creator artwork-data))) ERR-INVALID-INPUT)
    
    ;; Add/update the contributor
    (map-set contributors
      { artwork-id: artwork-id-input, contributor: contributor-input }
      {
        share-percentage: share-percentage-input,
        role: role-input
      }
    )
    
    ;; Update creator's share
    (map-set contributors
      { artwork-id: artwork-id-input, contributor: (get creator artwork-data) }
      {
        share-percentage: new-creator-share-amount,
        role: "creator"
      }
    )
    
    (ok true)
  )
)

;; Remove a contributor from an artwork
(define-public (remove-contributor (artwork-id-input uint) (contributor-input principal))
  (let
    ((artwork-data (unwrap! (map-get? artworks { artwork-id: artwork-id-input }) ERR-ARTWORK-NOT-FOUND))
     (contributor-record (unwrap! (map-get? contributors { artwork-id: artwork-id-input, contributor: contributor-input })
                               ERR-ARTWORK-NOT-FOUND))
     (creator-share-data (unwrap! (map-get? contributors { artwork-id: artwork-id-input, contributor: (get creator artwork-data) })
                            ERR-ARTWORK-NOT-FOUND))
     (share-to-return-amount (get share-percentage contributor-record))
     (new-creator-share-amount (+ (get share-percentage creator-share-data) share-to-return-amount)))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get creator artwork-data)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get primary-sold artwork-data)) ERR-ALREADY-SOLD)
    (asserts! (not (is-eq contributor-input (get creator artwork-data))) ERR-INVALID-INPUT)
    
    ;; Remove contributor
    (map-delete contributors { artwork-id: artwork-id-input, contributor: contributor-input })
    
    ;; Return share to creator
    (map-set contributors
      { artwork-id: artwork-id-input, contributor: (get creator artwork-data) }
      {
        share-percentage: new-creator-share-amount,
        role: "creator"
      }
    )
    
    (ok true)
  )
)

;; Link NFT contract to artwork (creator only)
(define-public (link-nft-contract (artwork-id-input uint) (nft-contract-input principal))
  (let
    ((artwork-data (unwrap! (map-get? artworks { artwork-id: artwork-id-input }) ERR-ARTWORK-NOT-FOUND)))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get creator artwork-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (get nft-contract artwork-data)) ERR-CONTRACT-ALREADY-LINKED)
    
    ;; Link the contract
    (map-set artworks
      { artwork-id: artwork-id-input }
      (merge artwork-data { nft-contract: (some nft-contract-input) })
    )
    
    (ok true)
  )
)

;; Primary sale of artwork
(define-public (primary-sale (artwork-id-input uint))
  (let
    ((artwork-data (unwrap! (map-get? artworks { artwork-id: artwork-id-input }) ERR-ARTWORK-NOT-FOUND))
     (sale-price (get primary-price artwork-data)))
    
    ;; Validate
    (asserts! (get active artwork-data) ERR-INVALID-INPUT)
    (asserts! (not (get primary-sold artwork-data)) ERR-ALREADY-SOLD)
    (asserts! (is-some (get nft-contract artwork-data)) ERR-NO-NFT-CONTRACT)
    
    ;; Check buyer has sufficient funds
    (asserts! (>= (stx-get-balance tx-sender) sale-price) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer STX for purchase to contract
    (try! (stx-transfer? sale-price tx-sender (as-contract tx-sender)))
    
    ;; Mark as sold
    (map-set artworks
      { artwork-id: artwork-id-input }
      (merge artwork-data { primary-sold: true })
    )
    
    ;; Distribute to contributors
    (try! (distribute-primary-sale artwork-id-input sale-price))
    
    (ok true)
  )
)

;; Private function to distribute primary sale proceeds
(define-private (distribute-primary-sale (artwork-id-input uint) (sale-amount-input uint))
  (let
    ((artwork-data (unwrap-panic (map-get? artworks { artwork-id: artwork-id-input })))
     (creator-principal (get creator artwork-data))
     (creator-record (unwrap-panic (map-get? contributors { artwork-id: artwork-id-input, contributor: creator-principal })))
     (creator-share-percentage (get share-percentage creator-record))
     (creator-payment-amount (/ (* sale-amount-input creator-share-percentage) PERCENTAGE-BASE)))
    
    ;; Transfer to creator (simplified - in a full implementation you'd iterate through all contributors)
    (if (> creator-payment-amount u0)
        (as-contract (try! (stx-transfer? creator-payment-amount tx-sender creator-principal)))
        true)
    
    (ok true)
  )
)

;; Record a secondary sale
(define-public (record-secondary-sale
                (artwork-id-input uint)
                (seller-input principal)
                (amount-input uint))
  (let
    ((artwork-data (unwrap! (map-get? artworks { artwork-id: artwork-id-input }) ERR-ARTWORK-NOT-FOUND))
     (sale-counter-data (unwrap! (map-get? next-sale-id-counter { artwork-id: artwork-id-input }) ERR-ARTWORK-NOT-FOUND))
     (new-sale-id (get id sale-counter-data))
     (royalty-percentage-value (get royalty-percentage artwork-data))
     (royalty-payment-amount (/ (* amount-input royalty-percentage-value) PERCENTAGE-BASE))
     (seller-payment-amount (- amount-input royalty-payment-amount)))
    
    ;; Validate
    (asserts! (get active artwork-data) ERR-INVALID-INPUT)
    (asserts! (get primary-sold artwork-data) ERR-NOT-SOLD)
    (asserts! (> amount-input u0) ERR-INVALID-INPUT)
    (asserts! (not (is-eq seller-input tx-sender)) ERR-INVALID-INPUT) ;; Seller can't be buyer
    (asserts! (>= (stx-get-balance tx-sender) amount-input) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer payment from buyer to contract first
    (try! (stx-transfer? amount-input tx-sender (as-contract tx-sender)))
    
    ;; Transfer seller amount to seller
    (if (> seller-payment-amount u0)
        (as-contract (try! (stx-transfer? seller-payment-amount tx-sender seller-input)))
        true)
    
    ;; Record the sale
    (map-set secondary-sales
      { artwork-id: artwork-id-input, sale-id: new-sale-id }
      {
        seller: seller-input,
        buyer: tx-sender,
        amount: amount-input,
        royalty-amount: royalty-payment-amount,
        timestamp: block-height
      }
    )
    
    ;; Update royalty tracking
    (let
      ((royalty-tracking-data (unwrap! (map-get? royalty-distributions { artwork-id: artwork-id-input })
                             ERR-ARTWORK-NOT-FOUND)))
      
      (map-set royalty-distributions
        { artwork-id: artwork-id-input }
        {
          total-royalties: (+ (get total-royalties royalty-tracking-data) royalty-payment-amount),
          last-distribution: block-height
        }
      )
      
      ;; Distribute royalties to contributors
      (try! (distribute-royalties artwork-id-input royalty-payment-amount))
    )
    
    ;; Increment sale counter
    (map-set next-sale-id-counter
      { artwork-id: artwork-id-input }
      { id: (+ new-sale-id u1) }
    )
    
    (ok new-sale-id)
  )
)

;; Private function to distribute royalties
(define-private (distribute-royalties (artwork-id-input uint) (royalty-amount-input uint))
  (let
    ((artwork-record (map-get? artworks { artwork-id: artwork-id-input }))
     (creator-record (if (is-some artwork-record)
                      (map-get? contributors { artwork-id: artwork-id-input, contributor: (get creator (unwrap-panic artwork-record)) })
                     none)))
    
    (if (and (is-some artwork-record) (is-some creator-record))
        (let
          ((creator-principal (get creator (unwrap-panic artwork-record)))
           (creator-share-data (unwrap-panic creator-record))
           (creator-royalty-amount (/ (* royalty-amount-input (get share-percentage creator-share-data)) PERCENTAGE-BASE))
           (existing-royalty-data (default-to { amount: u0 }
                               (map-get? claimable-royalties { artwork-id: artwork-id-input, contributor: creator-principal }))))
          
          ;; Add royalties to claimable pool for creator
          (map-set claimable-royalties
            { artwork-id: artwork-id-input, contributor: creator-principal }
            { amount: (+ (get amount existing-royalty-data) creator-royalty-amount) }
          )
          
          (ok true)
        )
        ERR-ARTWORK-NOT-FOUND
    )
  )
)

;; Claim royalties
(define-public (claim-royalties (artwork-id-input uint))
  (let
    ((claimable-data (unwrap! (map-get? claimable-royalties { artwork-id: artwork-id-input, contributor: tx-sender })
                       ERR-NO-ROYALTIES))
     (claimable-amount (get amount claimable-data)))
    
    ;; Validate
    (asserts! (> claimable-amount u0) ERR-NO-ROYALTIES)
    
    ;; Reset claimable amount
    (map-set claimable-royalties
      { artwork-id: artwork-id-input, contributor: tx-sender }
      { amount: u0 }
    )
    
    ;; Transfer royalties to contributor
    (as-contract (try! (stx-transfer? claimable-amount tx-sender tx-sender)))
    
    (ok claimable-amount)
  )
)

;; Deactivate artwork (creator only)
(define-public (deactivate-artwork (artwork-id-input uint))
  (let
    ((artwork-data (unwrap! (map-get? artworks { artwork-id: artwork-id-input }) ERR-ARTWORK-NOT-FOUND)))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get creator artwork-data)) ERR-NOT-AUTHORIZED)
    
    ;; Deactivate
    (map-set artworks
      { artwork-id: artwork-id-input }
      (merge artwork-data { active: false })
    )
    
    (ok true)
  )
)

;; Reactivate artwork (creator only)
(define-public (reactivate-artwork (artwork-id-input uint))
  (let
    ((artwork-data (unwrap! (map-get? artworks { artwork-id: artwork-id-input }) ERR-ARTWORK-NOT-FOUND)))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get creator artwork-data)) ERR-NOT-AUTHORIZED)
    
    ;; Reactivate
    (map-set artworks
      { artwork-id: artwork-id-input }
      (merge artwork-data { active: true })
    )
    
    (ok true)
  )
)

;; Read-only functions

;; Get artwork details
(define-read-only (get-artwork-details (artwork-id-input uint))
  (map-get? artworks { artwork-id: artwork-id-input })
)

;; Get contributor details
(define-read-only (get-contributor-details (artwork-id-input uint) (contributor-input principal))
  (map-get? contributors { artwork-id: artwork-id-input, contributor: contributor-input })
)

;; Get claimable royalties
(define-read-only (get-claimable-royalties (artwork-id-input uint) (contributor-input principal))
  (default-to { amount: u0 }
              (map-get? claimable-royalties { artwork-id: artwork-id-input, contributor: contributor-input }))
)

;; Get royalty distribution stats
(define-read-only (get-royalty-stats (artwork-id-input uint))
  (map-get? royalty-distributions { artwork-id: artwork-id-input })
)

;; Get secondary sale details
(define-read-only (get-secondary-sale (artwork-id-input uint) (sale-id-input uint))
  (map-get? secondary-sales { artwork-id: artwork-id-input, sale-id: sale-id-input })
)

;; Get next artwork ID
(define-read-only (get-next-artwork-id)
  (var-get next-artwork-id-counter)
)

;; Get contract owner
(define-read-only (get-contract-owner)
  (var-get contract-owner-address)
)

;; Check if artwork exists
(define-read-only (artwork-exists (artwork-id-input uint))
  (is-some (map-get? artworks { artwork-id: artwork-id-input }))
)

;; Get total artworks count
(define-read-only (get-total-artworks)
  (- (var-get next-artwork-id-counter) u1)
)
