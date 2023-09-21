//
//  NCCCountdownTimer.swift
//  NCCCountdownTimer
//
//  Created by Andrew Benson on 9/18/23.
//  Copyright (C) 2023 Nuclear Cyborg Corp
//
//
import SwiftUI
import OSLog

@available(iOS 15.0, *)
class NCCCountdownTimer: NSObject, ObservableObject {
    /// Logging subsystem and category
    private let logger = Logger(subsystem: "VisualTimer", category: "NCCCountdownTimer")

    /// The current mode of the NCCCountdownTimer
    enum Mode {
        /// Timer is not running and has `interval` seconds remaining
        case stopped(interval: TimeInterval)

        /// Timer is running and will expire at `expirationDate`
        case running(expirationTime: Date)

        /// Timer has expired
        case expired

        /// Returns `true` if the timer is running.  Else `false`.
        var isTimerRunning: Bool {
            switch self {
            case .stopped(_), .expired:
                return false
            default:
                return true
            }
        }
    }

    /// Read / write -- reports and controls the current coutdown timer mode.
    @Published public var mode: Mode = .stopped(interval: 60.0) {
        didSet {
            if mode.isTimerRunning && displayLink.isPaused {
                displayLink.isPaused = false
                logger.debug("mode didSet: displayLink.isPaused = false")
            } else if !mode.isTimerRunning && !displayLink.isPaused {
                displayLink.isPaused = true
                logger.debug("mode didSet: displayLink.isPaused = true")
            }
        }
    }

    /// The number of seconds remaining on the timer.  Can also be set.
    public var interval: TimeInterval {
        get {
            switch mode {
            case .stopped(let interval):
                return interval
            case .running(let expirationTime):
                return expirationTime.timeIntervalSinceNow
            case .expired:
                return 0.0
            }
        }
        set {
            self.objectWillChange.send()
            switch newValue {
            case _ where newValue < 0:
                logger.error("interval: ignored invalid negative value \(newValue, privacy: .public)")
            case 0:
                mode = .expired
            default:
                if !mode.isTimerRunning {
                    mode = .stopped(interval: newValue)
                } else {
                    mode = .running(expirationTime: Date.now.addingTimeInterval(newValue))
                }
            }
        }
    }

    /// Internal -- create a `CADisplayLink` to set up periodic callbacks
    private lazy var displayLink: CADisplayLink = {
        let displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink.isPaused = true
        return displayLink
    }()

    /// Called by the `CADisplayLink` to indicate a display frame has advanced
    @objc private func update() {
        // Call `objectWillChange.send()` to make sure clients see the new time remaining
        self.objectWillChange.send()
        if interval <= 0 {
            mode = .expired
        }
    }

    /// Pauses / stops the timer, if it is running
    func pause() {
        guard mode.isTimerRunning else { return }
        mode = .stopped(interval: interval)
    }

    /// Starts the timer, if it is currently stopped
    func start() {
        guard case Mode.stopped(let interval) = mode else { return }
        mode = .running(expirationTime: Date.now.addingTimeInterval(interval))
    }

    /// Init and get display link ready
    override init() {
        super.init()
        displayLink.add(to: .main, forMode: .common)
    }
}
