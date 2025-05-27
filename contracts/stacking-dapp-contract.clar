
;; stacking-dapp-contract
;; A decentralized staking application for Stacks blockchain

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-staked (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-minimum-not-met (err u105))
(define-constant err-staking-locked (err u106))
(define-constant err-not-staked (err u107))
(define-constant err-cooldown-period (err u108))
(define-constant err-pool-full (err u109))
(define-constant err-invalid-duration (err u110))

(define-constant min-staking-amount u100000000) ;; 100 STX minimum
(define-constant max-pool-size u1000000000000) ;; 1M STX max pool size
(define-constant reward-cycle-length u144) ;; ~1 day in blocks
(define-constant cooldown-period u72) ;; ~12 hours in blocks

;; data maps and vars
(define-data-var total-staked uint u0)
(define-data-var staking-enabled bool true)
(define-data-var current-cycle uint u0)
(define-data-var pool-rewards-per-cycle uint u50000000) ;; 50 STX per cycle

(define-map staker-info 
  { staker: principal } 
  {
    amount: uint,
    rewards-claimed: uint,
    unlock-height: uint,
    last-reward-cycle: uint,
    staking-duration: uint
  }
)

(define-map cycle-rewards 
  { cycle: uint } 
  { total-reward: uint }
)

(define-map staker-by-cycle
  { cycle: uint, staker: principal }
  { participated: bool }
)

;; private functions
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner)
)

(define-private (calculate-reward (staker principal) (amount uint) (duration uint))
  (let (
    (base-reward (/ (* amount duration) u10000))
    (bonus (if (>= duration u6) (/ amount u100) u0))
  )
    (+ base-reward bonus)
  )
)

(define-private (get-current-reward-cycle)
  (let (
    (current-block-height block-height)
  )
    (/ current-block-height reward-cycle-length)
  )
)

(define-private (update-reward-cycle)
  (let (
    (new-cycle (get-current-reward-cycle))
  )
    (if (> new-cycle (var-get current-cycle))
      (begin
        (var-set current-cycle new-cycle)
        (map-set cycle-rewards { cycle: new-cycle } { total-reward: (var-get pool-rewards-per-cycle) })
        (ok true)
      )
      (ok false)
    )
  )
)

;; read-only functions
(define-read-only (get-staker-info (staker principal))
  (default-to 
    { amount: u0, rewards-claimed: u0, unlock-height: u0, last-reward-cycle: u0, staking-duration: u0 } 
    (map-get? staker-info { staker: staker })
  )
)

(define-read-only (get-total-staked)
  (var-get total-staked)
)

(define-read-only (get-staking-status)
  (var-get staking-enabled)
)

(define-read-only (get-pending-rewards (staker principal))
  (let (
    (current-stake-info (get-staker-info staker))
    (staked-amount (get amount current-stake-info))
    (last-reward-cycle (get last-reward-cycle current-stake-info))
    (current-reward-cycle (var-get current-cycle))
    (duration (get staking-duration current-stake-info))
    (cycles-to-reward (- current-reward-cycle last-reward-cycle))
  )
    (if (> staked-amount u0)
      (calculate-reward staker staked-amount cycles-to-reward)
      u0
    )
  )
)

(define-read-only (get-unlock-time (staker principal))
  (let (
    (current-stake-info (get-staker-info staker))
    (unlock-height (get unlock-height current-stake-info))
  )
    (- unlock-height block-height)
  )
)

(define-read-only (can-unstake (staker principal))
  (let (
    (current-stake-info (get-staker-info staker))
    (unlock-height (get unlock-height current-stake-info))
    (staked-amount (get amount current-stake-info))
  )
    (and (> staked-amount u0) (>= block-height unlock-height))
  )
)

;; public functions
(define-public (stake (amount uint) (duration uint))
  (let (
    (staker tx-sender)
    (current-stake-info (default-to 
      { amount: u0, rewards-claimed: u0, unlock-height: u0, last-reward-cycle: u0, staking-duration: u0 } 
      (map-get? staker-info { staker: staker })))
    (new-total-staked (+ (var-get total-staked) amount))
    (unlock-height (+ block-height (* duration reward-cycle-length)))
  )
    (asserts! (var-get staking-enabled) err-staking-locked)
    (asserts! (is-eq (get amount current-stake-info) u0) err-already-staked)
    (asserts! (>= amount min-staking-amount) err-minimum-not-met)
    (asserts! (<= new-total-staked max-pool-size) err-pool-full)
    (asserts! (and (>= duration u1) (<= duration u12)) err-invalid-duration)
    
    (try! (stx-transfer? amount staker (as-contract tx-sender)))
    (var-set total-staked new-total-staked)
    (map-set staker-info 
      { staker: staker } 
      {
        amount: amount,
        rewards-claimed: u0,
        unlock-height: unlock-height,
        last-reward-cycle: (var-get current-cycle),
        staking-duration: duration
      }
    )
    (map-set staker-by-cycle
      { cycle: (var-get current-cycle), staker: staker }
      { participated: true }
    )
    (ok amount)
  )
)

(define-public (unstake)
  (let (
    (staker tx-sender)
    (current-stake-info (default-to 
      { amount: u0, rewards-claimed: u0, unlock-height: u0, last-reward-cycle: u0, staking-duration: u0 } 
      (map-get? staker-info { staker: staker })))
    (staked-amount (get amount current-stake-info))
    (unlock-height (get unlock-height current-stake-info))
  )
    (asserts! (> staked-amount u0) err-not-staked)
    (asserts! (>= block-height unlock-height) err-cooldown-period)
    
    (try! (as-contract (stx-transfer? staked-amount (as-contract tx-sender) staker)))
    (var-set total-staked (- (var-get total-staked) staked-amount))
    (map-delete staker-info { staker: staker })
    (ok staked-amount)
  )
)

(define-public (claim-rewards)
  (let (
    (staker tx-sender)
    (current-stake-info (default-to 
      { amount: u0, rewards-claimed: u0, unlock-height: u0, last-reward-cycle: u0, staking-duration: u0 } 
      (map-get? staker-info { staker: staker })))
    (staked-amount (get amount current-stake-info))
    (last-reward-cycle (get last-reward-cycle current-stake-info))
    (current-reward-cycle (var-get current-cycle))
    (duration (get staking-duration current-stake-info))
    (cycles-to-reward (- current-reward-cycle last-reward-cycle))
    (reward-amount (calculate-reward staker staked-amount cycles-to-reward))
  )
    (asserts! (> staked-amount u0) err-not-staked)
    (asserts! (> cycles-to-reward u0) err-already-staked)
    
    (try! (as-contract (stx-transfer? reward-amount (as-contract tx-sender) staker)))
    (map-set staker-info 
      { staker: staker } 
      (merge current-stake-info { 
        rewards-claimed: (+ (get rewards-claimed current-stake-info) reward-amount),
        last-reward-cycle: current-reward-cycle
      })
    )
    (ok reward-amount)
  )
)

(define-public (toggle-staking)
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (ok (var-set staking-enabled (not (var-get staking-enabled))))
  )
)

(define-public (update-pool-rewards (new-reward-amount uint))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (ok (var-set pool-rewards-per-cycle new-reward-amount))
  )
)

(define-public (emergency-withdraw (staker principal))
  (let (
    (current-stake-info (default-to 
      { amount: u0, rewards-claimed: u0, unlock-height: u0, last-reward-cycle: u0, staking-duration: u0 } 
      (map-get? staker-info { staker: staker })))
    (staked-amount (get amount current-stake-info))
  )
    (asserts! (is-contract-owner) err-owner-only)
    (asserts! (> staked-amount u0) err-not-staked)
    
    (try! (as-contract (stx-transfer? staked-amount (as-contract tx-sender) staker)))
    (var-set total-staked (- (var-get total-staked) staked-amount))
    (map-delete staker-info { staker: staker })
    (ok staked-amount)
  )
)
