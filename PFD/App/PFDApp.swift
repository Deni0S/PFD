import SwiftUI
import CoreMotion
import CoreLocation
import UIKit

// MARK: - Логика получения данных (Сенсоры)
final class FlightData: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var speed: Double = 0          // Скорость в км/ч
    @Published var speedTrend: Double = 0.0   // Тренд скорости
    @Published var altitude: Double = 0       // Высота в метрах
    @Published var variometer: Double = 0     // Вертикальная скорость (м/с)
    @Published var pitch: Double = 0          // Тангаж (наклон вперед/назад)
    @Published var roll: Double = 0           // Крен (наклон влево/вправо)
    @Published var yaw: Double = 0            // Рыскание (поворот вокруг оси)

    private let motionManager = CMMotionManager()
    private let altimeter = CMAltimeter()
    private let locationManager = CLLocationManager()

    private var baselinePitch: Double? = nil
    private var baselineRoll: Double? = nil
    private var lastAltitude: Double?
    private var lastAltitudeTime: Date?
    private var lastSpeed: Double = 0

    func start() {
        startMotion()
        startBarometer()
        startLocation()

        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
        locationManager.stopUpdatingLocation()
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    @objc private func orientationChanged() {
        // При повороте устройства текущее физическое положение становится "нулевой" точкой
        baselinePitch = nil
        baselineRoll = nil
    }

    private func startMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0

        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] m, _ in
            guard let self, let motion = m else { return }

            let g = motion.gravity
            var rawPitch: Double = 0
            var rawRoll: Double = 0

            // Правильный расчет углов для ЛАНДШАФТНОЙ ориентации
            // (ось Y телефона смотрит вправо, ось X — вверх)
            switch UIDevice.current.orientation {
            case .landscapeLeft:
                // Кнопка Home справа
                rawRoll = atan2(-g.y, -g.z) * 180.0 / .pi
                rawPitch = atan2(-g.x, sqrt(g.y*g.y + g.z*g.z)) * 180.0 / .pi
            case .landscapeRight:
                // Кнопка Home слева
                rawRoll = atan2(g.y, -g.z) * 180.0 / .pi
                rawPitch = atan2(g.x, sqrt(g.y*g.y + g.z*g.z)) * 180.0 / .pi
            default:
                // Портрет (на случай если приложение запущено вертикально)
                rawRoll = atan2(g.x, -g.y) * 180.0 / .pi
                rawPitch = atan2(-g.z, sqrt(g.x*g.x + g.y*g.y)) * 180.0 / .pi
            }

            if self.baselinePitch == nil { self.baselinePitch = rawPitch }
            if self.baselineRoll == nil { self.baselineRoll = rawRoll }

            var calcPitch = rawPitch - self.baselinePitch!
            var calcRoll = rawRoll - self.baselineRoll!

            // Нормализация
            if calcPitch > 180 { calcPitch -= 360 }
            if calcPitch < -180 { calcPitch += 360 }
            if calcRoll > 180 { calcRoll -= 360 }
            if calcRoll < -180 { calcRoll += 360 }

            // Сглаживание для плавности
            self.pitch = self.pitch * 0.9 + max(-90, min(90, calcPitch)) * 0.1
            self.roll = self.roll * 0.9 + max(-90, min(90, calcRoll)) * 0.1
            self.yaw = motion.attitude.yaw * 180.0 / .pi
        }
    }

    private func startBarometer() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            guard let self, let d = data else { return }
            let alt = d.relativeAltitude.doubleValue

            if let last = self.lastAltitude, let lastTime = self.lastAltitudeTime {
                let dt = Date().timeIntervalSince(lastTime)
                if dt > 0.05 {
                    let v = (alt - last) / dt
                    self.variometer = self.variometer * 0.8 + max(-30, min(30, v)) * 0.2
                }
            }
            self.lastAltitude = alt
            self.lastAltitudeTime = Date()
            self.altitude = alt
        }
    }

    private func startLocation() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }

        // Перевод м/с в км/ч
        let kmh = max(loc.speed, 0) * 3.6

        // Тренд скорости (разница между текущей и прошлой)
        let diff = kmh - lastSpeed
        self.speedTrend = max(-1, min(1, diff * 0.5))

        self.lastSpeed = kmh
        self.speed = kmh

        if !CMAltimeter.isRelativeAltitudeAvailable() {
            self.altitude = loc.altitude
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    // Оригинальная формула из UIKit кода для вариометра
    func variometerInRadian() -> Double {
        let v = self.variometer
        if 20 < v && v <= 30 { return (Double(v - 20) * 15 + 2500) / 1000 }
        else if 10 < v && v <= 20 { return (Double(v - 10) * 50 + 2000) / 1000 }
        else if 0 <= v && v <= 10 { return (Double(v) * 200) / 1000 }
        else if -10 <= v && v < 0 { return (Double(v) * 200) / 1000 }
        else if -20 <= v && v < -10 { return (Double(v + 10) * 50 - 2000) / 1000 }
        else if -30 <= v && v < -20 { return (Double(v + 20) * 15 - 2500) / 1000 }
        return 0
    }
}

// MARK: - Главный экран PFD
struct PFDView: View {
    @StateObject private var flight = FlightData()

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / 1366.0
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                Color.black.ignoresSafeArea()

                // 1. Горизонт (Skyline) - Двигается по высоте (Pitch) и наклоняется (Roll)
                Image("Skyline")
                    .resizable()
                    .frame(width: 4244 * scale, height: 4244 * scale)
                    .rotationEffect(.degrees(flight.roll)) // Поворот заваливает горизонт
                    .offset(y: CGFloat(flight.pitch) * 10 * scale) // Нос вверх -> горизонт вниз
                    .position(center)

                // 2. Шкала тангажа (Pitch) - Двигается синхронно с горизонтом
                Image("Pitch")
                    .resizable()
                    .frame(width: 300 * scale, height: 2200 * scale)
                    .offset(y: CGFloat(flight.pitch) * 10 * scale)
                    .position(center)

                // 3. Крылья (Wing) - Статичны
                Image("Wing")
                    .resizable()
                    .frame(width: 500 * scale, height: 70 * scale)
                    .position(center)

                // 4. Указатель рыскания (Yaw)
                Image("Yaw")
                    .resizable()
                    .frame(width: 50 * scale, height: 15 * scale)
                    .offset(x: CGFloat(flight.yaw) * 2 * scale, y: 44 * scale)
                    .position(center)

                // 5. Указатель крена (RollPointer) - Поворачивается вместе с горизонтом
                Image("RollPointer")
                    .resizable()
                    .frame(width: 50 * scale, height: 42 * scale)
                    .rotationEffect(.degrees(-flight.roll))
                    .offset(y: -365 * scale)
                    .position(center)

                // 6. Дуга крена (RollScale) - Статична
                Image("RollScale")
                    .resizable()
                    .frame(width: 600 * scale, height: 300 * scale)
                    .position(x: center.x, y: 102 * scale + (300 * scale / 2))

                // 7. Прибор скорости (Слева)
                speedInstrument(scale: scale)
                    .frame(width: 170 * scale, height: 750 * scale)
                    .position(x: 100 * scale + (170 * scale / 2), y: center.y)

                // 8. Прибор высоты (Справа)
                altimeterInstrument(scale: scale)
                    .frame(width: 170 * scale, height: 750 * scale)
                    .position(x: geo.size.width - 100 * scale - (170 * scale / 2), y: center.y)

                // 9. Вариометр (Крайний справа)
                variometerInstrument(scale: scale)
                    .frame(width: 70 * scale, height: 400 * scale)
                    .position(x: geo.size.width - 15 * scale - (70 * scale / 2), y: center.y)
            }
        }
        .onAppear { flight.start() }
        .onDisappear { flight.stop() }
        .statusBarHidden(true)
    }

    // MARK: - Компоненты приборов

    @ViewBuilder
    private func speedInstrument(scale: CGFloat) -> some View {
        ZStack {
            // Движущаяся лента скорости
            Image("Speed")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 170 * scale, height: 7202 * scale)
                // Скорость в км/ч двигает ленту (10 pt на 1 км/ч)
                .offset(y: CGFloat(flight.speed) * 10 * scale)
                .clipped()

            // Черное окно со значением скорости
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    // Выводим точное значение скорости до км/ч
                    Text("\(Int(flight.speed))")
                        .font(.system(size: 60 * scale, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Индикатор тренда скорости
                    Image("Trend")
                        .resizable()
                        .frame(width: 20 * scale, height: 426.5 * scale)
                        .scaleEffect(y: max(0.01, flight.speedTrend), anchor: .center)
                        .frame(width: 20 * scale, height: 90 * scale)
                }
                .frame(width: 150 * scale, height: 90 * scale)
                .background(Color.black)
                .overlay(Rectangle().stroke(Color.white, lineWidth: 5 * scale))
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func altimeterInstrument(scale: CGFloat) -> some View {
        ZStack {
            // Движущаяся лента высоты
            Image("Altimeter")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 170 * scale, height: 14404 * scale)
                // Высота в метрах двигает ленту (1.2 pt на 1 метр)
                .offset(y: CGFloat(flight.altitude) * 1.2 * scale)
                .clipped()

            // Черное окно со значением высоты
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    // Выводим точное значение высоты в метрах
                    Text("\(Int(flight.altitude))")
                        .font(.system(size: 56 * scale, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .minimumScaleFactor(0.5) // Уменьшаем шрифт, если цифр много
                        .lineLimit(1)
                }
                .frame(width: 150 * scale, height: 90 * scale)
                .background(Color.black)
                .overlay(Rectangle().stroke(Color.white, lineWidth: 5 * scale))
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func variometerInstrument(scale: CGFloat) -> some View {
        ZStack {
            // Шкала вариометра
            Image("Variometer")
                .resizable()
                .frame(width: 70 * scale, height: 400 * scale)

            // Стрелка вариометра (Вращается вокруг правого края)
            Image("VariometerArrow")
                .resizable()
                .frame(width: 205 * scale, height: 5 * scale)
                .rotationEffect(.radians(.pi * flight.variometerInRadian() / 6), anchor: .trailing)
                // Смещаем так, чтобы основание стрелки было в центре
                .offset(x: -102.5 * scale)
        }
        .clipped()
    }
}

// MARK: - Точка входа
@main
struct PFDApp: App {
    var body: some Scene {
        WindowGroup {
            PFDView()
                .preferredColorScheme(.dark)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}
