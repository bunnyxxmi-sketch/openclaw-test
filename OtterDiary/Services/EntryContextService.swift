import Foundation
import CoreLocation

struct EntryContext {
    let location: String
    let weather: String

    static let fallback = EntryContext(location: "未知地点", weather: "天气不可用")
}

actor EntryContextService {
    func fetchContext() async -> EntryContext {
        guard let coordinate = await LocationProvider().requestCoordinate(timeout: 3.5) else {
            return .fallback
        }

        async let place = reverseGeocode(coordinate)
        async let weather = fetchWeather(coordinate)

        let resolvedLocation = await place ?? "未知地点"
        let resolvedWeather = await weather ?? "天气不可用"
        return EntryContext(location: resolvedLocation, weather: resolvedWeather)
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            guard let mark = placemarks.first else { return nil }
            let city = mark.locality ?? mark.subLocality
            let region = mark.administrativeArea
            if let city, let region, !city.isEmpty, !region.isEmpty {
                return "\(region)\(city)"
            }
            return city ?? region ?? mark.name
        } catch {
            return nil
        }
    }

    private func fetchWeather(_ coordinate: CLLocationCoordinate2D) async -> String? {
        var comp = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        comp?.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        guard let url = comp?.url else { return nil }

        var req = URLRequest(url: url)
        req.timeoutInterval = 4

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let payload = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let temp = Int(payload.current.temperature_2m.rounded())
            let desc = weatherDescription(code: payload.current.weather_code)
            return "\(desc) \(temp)°C"
        } catch {
            return nil
        }
    }

    private func weatherDescription(code: Int) -> String {
        switch code {
        case 0: return "晴"
        case 1, 2: return "多云"
        case 3: return "阴"
        case 45, 48: return "雾"
        case 51, 53, 55, 56, 57: return "毛毛雨"
        case 61, 63, 65, 66, 67, 80, 81, 82: return "雨"
        case 71, 73, 75, 77, 85, 86: return "雪"
        case 95, 96, 99: return "雷雨"
        default: return "天气"
        }
    }
}

private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let weather_code: Int
    }

    let current: Current
}

private final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func requestCoordinate(timeout: TimeInterval) async -> CLLocationCoordinate2D? {
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>) in
                self.continuation = continuation
                manager.requestWhenInUseAuthorization()
                manager.requestLocation()

                Task {
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    self.resume(nil)
                }
            }
        } onCancel: {
            resume(nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        resume(locations.last?.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        resume(nil)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            resume(nil)
        }
    }

    private func resume(_ coordinate: CLLocationCoordinate2D?) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: coordinate)
    }
}
