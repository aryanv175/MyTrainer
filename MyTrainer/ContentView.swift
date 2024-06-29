//
//  ContentView.swift
//  MyTrainer
//
//  Created by Aryan Verma on 27/06/24.
//

import SwiftUI
import AVFoundation

struct Exercise: Identifiable {
    var id = UUID()
    var name: String
    var duration: Int
    var spokenInstruction: String?
    var hasBeenSpoken = false
}

struct ContentView: View {
    @State private var exerciseName: String = ""
    @State private var selectedDuration: Double = 60.0
    @State private var exercises: [Exercise] = []
    @State private var isEditingEnabled: Bool = true
    @State private var isSaveClicked: Bool = false
    @State private var isTimerRunning: Bool = false
    @State private var remainingTime: Int = 0
    @State private var currentExerciseIndex: Int = 0
    @State private var showCongratulationsPopup: Bool = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let speechSynthesizer = AVSpeechSynthesizer()

    var totalDuration: Int {
        exercises.reduce(0) { $0 + $1.duration }
    }

    var formattedDuration: String {
        let minutes = remainingTime / 60
        let seconds = remainingTime % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if !exercises.isEmpty {
                    Text("Current Workout")
                        .font(.largeTitle)
                        .padding(.top)
                }

                VStack(spacing: 0) {
                    List {
                        ForEach(exercises.indices, id: \.self) { index in
                            let exercise = exercises[index]
                            HStack {
                                Text("\(exercise.name) - \(exercise.duration) seconds")
                                    .padding()
                                    .background(isTimerRunning && currentExerciseIndex == index ? Color.yellow.opacity(0.5) : Color.clear)
                                    .cornerRadius(10)

                                Spacer()

                                Button(action: {
                                    deleteExercise(at: IndexSet(integer: index))
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .disabled(isTimerRunning)
                            }
                        }
                        .onDelete(perform: deleteExercise)
                    }
                    .listStyle(PlainListStyle())
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .padding(.horizontal)

                if isEditingEnabled {
                    TextField("", text: $exerciseName, prompt: Text("Enter Exercise Name"))
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black, lineWidth: 1)
                        )
                        .disabled(isTimerRunning)
                        .foregroundColor(.black)
                        .padding(.horizontal)

                    VStack {
                        Text("Select duration")
                        Text("\(Int(selectedDuration)) seconds")
                            .font(.headline)
                            .padding(.vertical, 10)

                        Slider(value: $selectedDuration, in: 10...600, step: 10)
                            .padding(.horizontal)
                            .disabled(isTimerRunning)
                    }
                }

                if !isSaveClicked {
                    HStack(spacing: 20) {
                        Button(action: addExercise) {
                            Text("Add Exercise")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, maxHeight: 50)
                                .background(Color.gray)
                                .cornerRadius(10)
                        }
                        .disabled(!isEditingEnabled || isTimerRunning)

                        Button(action: saveExercises) {
                            Text("Save")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, maxHeight: 50)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                }

                if isSaveClicked {
                    Text("Total Duration: \(formattedDuration)")
                        .font(.headline)
                        .padding(.top, 10)
                    if !isTimerRunning {
                        Button(action: startWorkout) {
                            Text("Start Workout")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, maxHeight: 50)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    } else {
                        Button(action: stopWorkout) {
                            Text("Stop Workout")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, maxHeight: 50)
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer()
            }
            .navigationTitle("💪 MyTrainer")
            .onReceive(timer) { _ in
                if isTimerRunning {
                    if remainingTime > 0 {
                        remainingTime -= 1
                        if remainingTime == 0 {
                            currentExerciseIndex += 1
                            if currentExerciseIndex < exercises.count {
                                remainingTime = exercises[currentExerciseIndex].duration
                                speakExerciseInstruction()
                            } else {
                                stopWorkout()
                                showCongratulationsPopup = true
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showCongratulationsPopup) {
                CongratulationsPopup(onDismiss: {
                    showCongratulationsPopup = false
                    isEditingEnabled = true
                    isSaveClicked = false
                    exercises.removeAll()
                    remainingTime = 0
                })
            }
        }
    }

    private func addExercise() {
        guard !exerciseName.isEmpty else { return }
        let exercise = Exercise(name: exerciseName, duration: Int(selectedDuration), spokenInstruction: "\(exerciseName) for \(Int(selectedDuration)) seconds")
        exercises.append(exercise)
        exerciseName = ""
        selectedDuration = 60.0
        updateRemainingTime()
    }

    private func saveExercises() {
        isEditingEnabled = false
        isSaveClicked = true
        updateRemainingTime()
    }

    private func deleteExercise(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
        updateRemainingTime()
    }

    private func updateRemainingTime() {
        remainingTime = totalDuration
    }

    private func startWorkout() {
        isTimerRunning = true
        currentExerciseIndex = 0
        remainingTime = exercises.first?.duration ?? 0
        speakExerciseInstruction()
    }

    private func speakExerciseInstruction() {
        guard currentExerciseIndex < exercises.count else {
            stopWorkout()
            return
        }

        let currentExercise = exercises[currentExerciseIndex]

        if let spokenInstruction = currentExercise.spokenInstruction {
            speakText(spokenInstruction)
            exercises[currentExerciseIndex].hasBeenSpoken = true
        }
    }

    private func speakText(_ text: String) {
        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speechSynthesizer.speak(speechUtterance)
    }

    private func stopWorkout() {
        isTimerRunning = false
        currentExerciseIndex = 0
        updateRemainingTime()
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
}

struct ConfettiShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }
}

struct CongratulationsPopup: View {
    var onDismiss: () -> Void
    
    @State private var confettiPieces: [ConfettiPiece] = []
    @State private var animationTrigger = false
    
    var body: some View {
        VStack {
            Text("Congratulations!")
                .font(.title)
                .padding()

            Text("You completed your workout!")
                .padding()

            Button(action: {
                withAnimation {
                    onDismiss()
                }
            }) {
                Text("Great")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(10)
            }
            .padding()

            ZStack {
                ForEach(confettiPieces) { piece in
                    ConfettiShape()
                        .foregroundColor(piece.color)
                        .frame(width: piece.size, height: piece.size)
                        .offset(x: piece.initialOffset.width, y: animationTrigger ? UIScreen.main.bounds.height + 100 : piece.initialOffset.height)
                        .rotationEffect(.degrees(piece.rotation))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .onAppear {
            generateConfettiPieces()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 4)) {
                    animationTrigger = true
                }
            }
        }
    }
    
    private func generateConfettiPieces() {
        let colors: [Color] = [.red, .blue, .yellow, .green, .orange, .purple]
        
        for _ in 0..<200 {
            let size = CGFloat.random(in: 5...15)
            let rotation = Double.random(in: 0...360)
            let color = colors.randomElement()!
            let initialOffset = CGSize(
                width: CGFloat.random(in: -UIScreen.main.bounds.width/2...UIScreen.main.bounds.width/2),
                height: CGFloat.random(in: -200...0)
            )
            
            confettiPieces.append(ConfettiPiece(size: size, rotation: rotation, color: color, initialOffset: initialOffset))
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let size: CGFloat
    let rotation: Double
    let color: Color
    let initialOffset: CGSize
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
