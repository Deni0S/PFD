import SwiftUI

struct PFDView: View {
    @StateObject private var flight = FlightData()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / 1366.0, geo.size.height / 1024.0)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                Color.black.ignoresSafeArea()

                // 1. Горизонт (Абсолютные углы)
                Image("Skyline")
                    .resizable()
                    .frame(width: 4244 * scale, height: 4244 * scale)
                    .rotationEffect(.degrees(-flight.roll))
                    .offset(y: CGFloat(flight.pitch) * PFD.pitchPointsPerDegree * scale)
                    .position(center)

                // 2. Шкала тангажа
                Image("Pitch")
                    .resizable()
                    .frame(width: 300 * scale, height: 2200 * scale)
                    .offset(y: CGFloat(flight.pitch) * PFD.pitchPointsPerDegree * scale)
                    .position(center)
                    .mask(
                        RoundedRectangle(cornerRadius: 50 * scale)
                            .frame(width: 300 * scale, height: 605 * scale)
                            .position(center)
                    )

                // 3. Крылья
                Image("Wing")
                    .resizable()
                    .frame(width: 500 * scale, height: 70 * scale)
                    .position(center)

                // 4. Указатель рыскания
                Image("Yaw")
                    .resizable()
                    .frame(width: 50 * scale, height: 15 * scale)
                    .offset(x: CGFloat(flight.yaw) * PFD.yawPointsPerDegree * scale, y: 44 * scale)
                    .position(center)

                // 5. Указатель крена
                Image("RollPointer")
                    .resizable()
                    .frame(width: 50 * scale, height: 42 * scale)
                    .rotationEffect(.degrees(flight.roll), anchor: .bottom)
                    .position(x: center.x, y: 102 * scale)

                // 6. Дуга крена
                Image("RollScale")
                    .resizable()
                    .frame(width: 600 * scale, height: 300 * scale)
                    .position(x: center.x, y: 102 * scale + (300 * scale / 2))

                // 7. Скорость (Слева)
                speedInstrument(scale: scale)
                    .frame(width: 170 * scale, height: 750 * scale)
                    .position(x: 100 * scale + (170 * scale / 2), y: center.y)

                // 8. Высота (Справа)
                altimeterInstrument(scale: scale)
                    .frame(width: 170 * scale, height: 750 * scale)
                    .position(x: geo.size.width - 100 * scale - (170 * scale / 2), y: center.y)

                // 9. Вариометр (Крайний справа)
                variometerInstrument(scale: scale)
                    .frame(width: 70 * scale, height: 400 * scale)
                    .position(x: geo.size.width - 15 * scale - (70 * scale / 2), y: center.y)
            }
            .animation(.linear(duration: 1.0/60.0), value: flight.pitch)
            .animation(.linear(duration: 1.0/60.0), value: flight.roll)
            .animation(.linear(duration: 1.0/60.0), value: flight.speed)
            .animation(.linear(duration: 1.0/60.0), value: flight.altitude)
        }
        .onAppear { flight.start() }
        .onDisappear { flight.stop() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background { flight.stop() }
            else if newPhase == .active { flight.start() }
        }
        .statusBarHidden(true)
    }

    // MARK: - Прибор Скорости
    @ViewBuilder
    private func speedInstrument(scale: CGFloat) -> some View {
        ZStack {
            // Лента скорости
            Rectangle()
                .fill(Color.black.opacity(0.4))
                .frame(width: 170 * scale, height: 750 * scale)
                .overlay(
                    Image("Speed")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 170 * scale, height: 7202 * scale)
                        .offset(y: CGFloat(flight.speed) * PFD.speedPointsPerUnit * scale)
                )
                .clipped()

            // Окно с цифрами (левая шкала)
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    // Целая часть
                    Text("\(Int(flight.speed))")
                        .font(.system(size: 56 * scale, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .minimumScaleFactor(0.5)

                    // Десятые доли (мелкий счетчик)
                    Text(String(format: "%01d", Int((flight.speed * 10).truncatingRemainder(dividingBy: 10))))
                        .font(.system(size: 24 * scale, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 25 * scale, alignment: .center)

                    // Тренд
                    Image("Trend")
                        .resizable()
                        .frame(width: 20 * scale, height: 426.5 * scale)
                        .scaleEffect(y: max(0.01, abs(flight.speedTrend)), anchor: .center)
                        .frame(width: 20 * scale, height: 90 * scale)
                }
                .frame(width: 150 * scale, height: 90 * scale)
                .background(Color.black)
                .overlay(Rectangle().stroke(Color.white, lineWidth: 5 * scale))
                Spacer()
            }
        }
    }

    // MARK: - Прибор Высоты
    @ViewBuilder
    private func altimeterInstrument(scale: CGFloat) -> some View {
        ZStack {
            // Лента высоты
            Rectangle()
                .fill(Color.black.opacity(0.4))
                .frame(width: 170 * scale, height: 750 * scale)
                .overlay(
                    Image("Altimeter")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 170 * scale, height: 14404 * scale)
                        .offset(y: CGFloat(flight.altitude) * PFD.altitudePointsPerMeter * scale)
                )
                .clipped()

            // Окно с цифрами
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    // Тысячи (если высота >= 1000)
                    if flight.altitude >= 1000 {
                        Text("\(Int(flight.altitude) / 1000)")
                            .font(.system(size: 40 * scale, weight: .regular, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 30 * scale, alignment: .center)
                    }

                    // Целая часть (метры)
                    Text(String(format: "%03d", Int(flight.altitude) % 1000))
                        .font(.system(size: 56 * scale, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .minimumScaleFactor(0.5)
                }
                .frame(width: 150 * scale, height: 90 * scale)
                .background(Color.black)
                .overlay(Rectangle().stroke(Color.white, lineWidth: 5 * scale))
                Spacer()
            }
        }
    }

    // MARK: - Вариометр (Используем PFD.variometerAngle)
    @ViewBuilder
    private func variometerInstrument(scale: CGFloat) -> some View {
        ZStack {
            // Шкала вариометра
            Image("Variometer")
                .resizable()
                .frame(width: 70 * scale, height: 400 * scale)

            // Стрелка вариометра
            Image("VariometerArrow")
                .resizable()
                .frame(width: 205 * scale, height: 5 * scale)
                // Используем новую математику с константами PFD
                .rotationEffect(.radians(flight.variometerAngle), anchor: .trailing)
                .offset(x: -102.5 * scale)
        }
        .clipped()
    }
}
