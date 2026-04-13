// Parlance/Core/Models/AudioFeatures.swift
import Foundation

struct AudioFeatures {
    let pitchMeanHz: Double
    let pitchStdDevHz: Double
    let energyMeanRMS: Double
    let energyStdDevRMS: Double

    static let empty = AudioFeatures(
        pitchMeanHz: 0, pitchStdDevHz: 0,
        energyMeanRMS: 0, energyStdDevRMS: 0
    )
}
