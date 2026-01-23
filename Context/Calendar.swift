//
//  Calendar.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import SwiftUI

struct CalendarSource: Identifiable {
    let id: String
    let name: String
    let url: String
    let color: Color
    
    static let predefinedCalendars: [CalendarSource] = [
        CalendarSource(
            id: "calendar1",
            name: "Family",
            url: "webcal://p136-caldav.icloud.com/published/2/MTg1NjU3MjgxODU2NTcyOJF3zorxWSzjlwNRhFs-nQOMgwqOi5TqcW_y3DjUixF-fBXphfllOhiA6Xg2JEdH7kalELH2Zr_N_taHh8MtK_E",
            color: .blue
        ),
        CalendarSource(
            id: "calendar2",
            name: "Martin",
            url: "webcal://p136-caldav.icloud.com/published/2/MTg1NjU3MjgxODU2NTcyOJF3zorxWSzjlwNRhFs-nQNhNqb8CNFc9EaUQFalQiOQC43qaqAfJa0PLsFkRRK7ZFIzOt7iLM_ny-n4Gbz1iz2boJ0LH1jka55K7thnI8A7736Rt6Dp7hLm6yt40L4mOA",
            color: .green
        ),
        CalendarSource(
            id: "calendar3",
            name: "Aurelius",
            url: "webcal://p136-caldav.icloud.com/published/2/MTg1NjU3MjgxODU2NTcyOJF3zorxWSzjlwNRhFs-nQNXU0uaPv8kf-Vp04CPljnn7ONwlxU_NNCuN9DiIQTHiYHchR_Jw-RgUWZlW2OXSEY",
            color: .red
        )
    ]
}
