import Foundation

/// Константы для отрисовки PFD.
/// Описывают, сколько пикселей (pt) приходится на единицу измерения.
enum PFD {
    // Скорость: 1 км/ч = 10 pt по шкале
    static let speedPointsPerUnit: Double = 10

    // Высота: 1 метр = 1.2 pt по шкале
    static let altitudePointsPerMeter: Double = 1.2

    // Тангаж: 1° = 10 pt смещения по вертикали
    static let pitchPointsPerDegree: Double = 10

    // Рыскание: 1° = 5 pt смещения по горизонтали
    static let yawPointsPerDegree: Double = 5

    // Вариометр
    static let variometerMaxAngle: Double = .pi / 4  // Максимальный угол отклонения стрелки (45°)
    static let variometerMaxRate: Double = 10        // Максимальная скорость (м/с)
}
