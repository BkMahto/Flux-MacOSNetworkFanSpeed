//
//  DisplayMode.swift
//  NetworkSpeedMeter
//
//  Created by Bandan.K on 29/01/26.
//

import Foundation

/// Display modes for the menu bar and dashboard.
enum DisplayMode: String, CaseIterable, Identifiable {
  case download = "Download"
  case upload = "Upload"
  case both = "Download + Upload"
  case combined = "Combined"
  case fan = "Fan Speed"
  case temperature = "Temperature"
  case fanAndTemp = "Fan + Temp"

  var id: String { self.rawValue }
}
