import Foundation
import CoreMotion
import CoreLocation
import UIKit

final class FlightData: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var speed: Double = 0          // км/ч
    @Published var speedTrend: Double = 0.0   // Тренд (-1.0 ... 1.0)
    @Published var altitude: Double = 0       // метры
    @Published var variometer: Double = 0     // м/с
    @Published var pitch: Double = 0          // градусы (абсолютный)
    @Published var roll: Double = 0           // градусы (абсолютный)
    @Published var yaw: Double = 0            // градусы (абсолютный)

    private let motionManager = CMMotionManager()
    private let altimeter = CMAltimeter()
    private let locationManager = CLLocationManager()

    private var lastAltitude: Double?
    private var lastAltitudeTime: Date?
    private var lastSpeed: Double = 0

    // Сглаживание
    private var smoothedSpeed: Double = 0
    private var smoothedVariometer: Double = 0
    private let smoothing: Double = 0.2

    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        isRunning = true

        startMotion()
        startBarometer()
        startLocation()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        motionManager.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
        locationManager.stopUpdatingLocation()
    }

    // MARK: - CoreMotion (Абсолютные углы)
    private func startMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0

        // Используем магнитометр и вертикаль для абсолютной ориентации
        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] motion, _ in
            guard let self, let m = motion else { return }

            // Абсолютные углы
            let pitchDeg = m.attitude.pitch * 180.0 / .pi
            let rollDeg  = m.attitude.roll  * 180.0 / .pi
            let yawDeg   = m.attitude.yaw   * 180.0 / .pi

            // Сглаживание
            self.pitch = self.pitch * 0.8 + pitchDeg * 0.2
            self.roll  = self.roll  * 0.8 + rollDeg * 0.2
            self.yaw   = self.yaw   * 0.8 + yawDeg * 0.2
        }
    }

    // MARK: - Barometer (Высота и вариометр)
    private func startBarometer() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            guard let self, let d = data else { return }
            let alt = d.relativeAltitude.doubleValue

            if let last = self.lastAltitude, let lastTime = self.lastAltitudeTime {
                let dt = Date().timeIntervalSince(lastTime)
                if dt > 0.05 {
                    let verticalSpeed = (alt - last) / dt
                    self.smoothedVariometer = self.smoothedVariometer * 0.8 + verticalSpeed * 0.2
                    // Ограничиваем максимальным значением из PFD
                    self.variometer = max(-PFD.variometerMaxRate * 3, min(PFD.variometerMaxRate * 3, self.smoothedVariometer))
                }
            }
            self.lastAltitude = alt
            self.lastAltitudeTime = Date()
            self.altitude = alt
        }
    }

    // MARK: - CoreLocation (Скорость)
    private func startLocation() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }

        // Скорость (м/с -> км/ч)
        let kmh = max(loc.speed, 0) * 3.6

        // Тренд скорости
        let diff = kmh - lastSpeed
        self.speedTrend = max(-1, min(1, diff * 0.5))

        self.lastSpeed = kmh
        self.smoothedSpeed = self.smoothedSpeed * 0.8 + kmh * 0.2
        self.speed = self.smoothedSpeed

        if !CMAltimeter.isRelativeAltitudeAvailable() {
            self.altitude = loc.altitude
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    // MARK: - Вариометр (Новая математика на основе констант PFD)
    /// Переводит текущую вертикальную скорость в угол наклона стрелки (в радианах).
    /// Использует PFD.variometerMaxAngle и PFD.variometerMaxRate.
    var variometerAngle: Double {
        // Ограничиваем значение от -30 до 30 (как в оригинальном коде, где шкала до 30)
        let clamped = max(-30, min(30, variometer))

        // В оригинальном коде была нелинейная шкала.
        // Мы адаптируем её под PFD константы.
        var normalized: Double
        if clamped >= 0 {
            normalized = clamped / 30.0 // 0.0 ... 1.0
        } else {
            normalized = clamped / 30.0 // -1.0 ... 0.0
        }

        // Умножаем на максимальный угол (45 градусов)
        return normalized * PFD.variometerMaxAngle
    }
}
