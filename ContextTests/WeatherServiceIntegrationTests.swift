//
//  WeatherServiceIntegrationTests.swift
//  ContextTests
//
//  Created by Martin on 25/01/2026.
//

import XCTest
@testable import Context

final class WeatherServiceIntegrationTests: XCTestCase {
    func testLiveWeatherFetch() async {
        let apiKey = OpenWeatherKey.value
        let latitude = -36.8485
        let longitude = 174.7633
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=imperial"

        guard let url = URL(string: urlString) else {
            XCTFail("Invalid URL for OpenWeather request.")
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                XCTFail("OpenWeather response was not HTTPURLResponse.")
                return
            }

            guard httpResponse.statusCode == 200 else {
                logFailure(
                    title: "OpenWeather returned non-200 status.",
                    statusCode: httpResponse.statusCode,
                    bodyData: data
                )
                return
            }

            do {
                let decoded = try JSONDecoder().decode(WeatherResponse.self, from: data)
                let weatherInfo = decoded.weather.first

                guard let weatherInfo else {
                    logFailure(
                        title: "OpenWeather returned empty weather array.",
                        statusCode: httpResponse.statusCode,
                        bodyData: data
                    )
                    return
                }

                guard decoded.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                    logFailure(
                        title: "OpenWeather returned empty location name.",
                        statusCode: httpResponse.statusCode,
                        bodyData: data
                    )
                    return
                }

                guard decoded.main.temp.isFinite else {
                    logFailure(
                        title: "OpenWeather returned non-finite temperature.",
                        statusCode: httpResponse.statusCode,
                        bodyData: data
                    )
                    return
                }

                guard (0...100).contains(decoded.main.humidity) else {
                    logFailure(
                        title: "OpenWeather returned humidity outside 0...100.",
                        statusCode: httpResponse.statusCode,
                        bodyData: data
                    )
                    return
                }

                guard decoded.wind.speed.isFinite, decoded.wind.speed >= 0 else {
                    logFailure(
                        title: "OpenWeather returned invalid wind speed.",
                        statusCode: httpResponse.statusCode,
                        bodyData: data
                    )
                    return
                }

                guard weatherInfo.main.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                    logFailure(
                        title: "OpenWeather returned empty condition string.",
                        statusCode: httpResponse.statusCode,
                        bodyData: data
                    )
                    return
                }

                guard weatherInfo.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                    logFailure(
                        title: "OpenWeather returned empty icon string.",
                        statusCode: httpResponse.statusCode,
                        bodyData: data
                    )
                    return
                }
            } catch {
                logFailure(
                    title: "OpenWeather JSON decode failed: \(error.localizedDescription)",
                    statusCode: httpResponse.statusCode,
                    bodyData: data
                )
            }
        } catch {
            XCTFail("OpenWeather request failed: \(error.localizedDescription)")
        }
    }

    private func logFailure(title: String, statusCode: Int, bodyData: Data) {
        let bodyString = String(data: bodyData, encoding: .utf8) ?? "<non-utf8 body>"
        let trimmedBody = bodyString.count > 1200 ? String(bodyString.prefix(1200)) + "…" : bodyString
        let message = """
        \(title)
        Status: \(statusCode)
        Response: \(trimmedBody)
        """
        XCTFail(message)
    }
}

private enum OpenWeatherKey {
    static let value: String = {
        let mask: UInt8 = 0x5A
        let encoded: [UInt8] = [
            110, 110, 111, 108, 99, 108, 63, 63, 111, 110, 109, 62, 63, 59, 57, 56,
            104, 104, 57, 57, 109, 104, 99, 104, 107, 105, 99, 63, 109, 59, 56, 109
        ]
        let bytes = encoded.map { $0 ^ mask }
        return String(bytes: bytes, encoding: .utf8) ?? "YOUR_API_KEY_HERE"
    }()
}
