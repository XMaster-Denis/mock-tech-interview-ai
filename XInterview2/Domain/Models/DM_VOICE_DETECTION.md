# DM_VOICE_DETECTION.md - Функционал детекции голоса

## Обзор

Документация детектора голосовой активности (Voice Activity Detection - VAD) приложения XInterview2.

## VoiceDetector

**Расположение:** [`XInterview2/Data/Audio/VoiceDetector.swift`](../../Data/Audio/VoiceDetector.swift:35)

**Описание:** Детектор голосовой активности для непрерывного распознавания речи. Использует фиксированный порог из настроек для надежного обнаружения речи.

### Published свойства

| Свойство | Тип | По умолчанию | Описание |
|-----------|------|----------------|-----------|
| [`isListening`](../../Data/Audio/VoiceDetector.swift:40) | `Bool` | `false` | Флаг прослушивания микрофона |
| [`audioLevel`](../../Data/Audio/VoiceDetector.swift:43) | `Float` | `0.0` | Текущий уровень аудио (0.0 - 1.0) |
| [`speechDetected`](../../Data/Audio/VoiceDetector.swift:46) | `Bool` | `false` | Флаг обнаружения речи |
| [`isSilenceTimerActive`](../../Data/Audio/VoiceDetector.swift:49) | `Bool` | `false` | Флаг активности таймера тишины |
| [`silenceTimerProgress`](../../Data/Audio/VoiceDetector.swift:52) | `Double` | `0.0` | Прогресс таймера тишины (0.0 - 1.0) |
| [`silenceTimerElapsed`](../../Data/Audio/VoiceDetector.swift:55) | `Double` | `0.0` | Прошедшее время в тишине (секунды) |

### Параметры конфигурации

| Параметр | Тип | По умолчанию | Диапазон | Описание |
|-----------|------|----------------|-----------|-----------|
| [`silenceThreshold`](../../Data/Audio/VoiceDetector.swift:61) | `Float` | `0.05` | - | Порог тишины для определения конца речи |
| [`speechStartThreshold`](../../Data/Audio/VoiceDetector.swift:64) | `Float` | `0.15` | `0.05 - 0.5` | Порог начала речи (настраивается через настройки) |
| [`silenceTimeout`](../../Data/Audio/VoiceDetector.swift:67) | `Double` | `1.5` | `0.5 - 5.0` | Тайм-аут тишины (настраивается через настройки) |
| [`minSpeechDuration`](../../Data/Audio/VoiceDetector.swift:70) | `TimeInterval` | `0.2` | - | Минимальная длительность речи для валидации |
| [`minSpeechLevel`](../../Data/Audio/VoiceDetector.swift:73) | `Float` | `0.04` | `0.01 - 0.1` | Минимальный средний уровень аудио для валидации речи |
| [`maxRecordingDuration`](../../Data/Audio/VoiceDetector.swift:76) | `TimeInterval` | `30.0` | - | Максимальная длительность записи |

### Callback

| Callback | Тип | Описание |
|----------|------|-----------|
| [`onVoiceEvent`](../../Data/Audio/VoiceDetector.swift:124) | `((VoiceEvent) -> Void)?` | Вызывается при событиях голосовой активности |

## События голосовой активности (VoiceEvent)

**Расположение:** [`XInterview2/Data/Audio/VoiceDetector.swift`](../../Data/Audio/VoiceDetector.swift:21)

| Событие | Тип | Описание |
|---------|------|-----------|
| [`speechStarted`](../../Data/Audio/VoiceDetector.swift:22) | - | Речь началась |
| [`speechEnded(Data)`](../../Data/Audio/VoiceDetector.swift:23) | `Data` | Речь закончилась (аудиоданные для транскрибации) |
| [`silenceDetected`](../../Data/Audio/VoiceDetector.swift:24) | - | Обнаружена тишина |
| [`error(Error)`](../../Data/Audio/VoiceDetector.swift:25) | `Error` | Произошла ошибка |

## Алгоритм детекции речи

### 1. Мониторинг уровня аудио

**Метод:** [`checkAudioLevel()`](../../Data/Audio/VoiceDetector.swift:318)

**Частота:** Каждые 0.05 секунды (20 раз в секунду)

**Процесс:**

1. Получение среднего уровня мощности аудио из [`AVAudioRecorder`](../../Data/Audio/VoiceDetector.swift:82)
2. Нормализация в диапазон 0.0 - 1.0 (от -60dB до 0dB)
3. Обновление [`audioLevel`](../../Data/Audio/VoiceDetector.swift:43) свойства

```swift
recorder.updateMeters()
let averagePower = recorder.averagePower(forChannel: 0)
let level = max(0.0, min(1.0, (averagePower + 60) / 60))
audioLevel = level
```

### 2. Детекция начала речи

**Условия:**
- `level > speechStartThreshold`
- `!isSpeechActive` (речь не активна)

**Действия:**
1. Установка `isSpeechActive = true`
2. Сохранение времени начала речи
3. Установка `speechDetected = true`
4. Отмена таймера тишины
5. Отправка события [`speechStarted`](../../Data/Audio/VoiceDetector.swift:22)
6. Логирование события

```swift
if isAboveThreshold && !isSpeechActive {
    isSpeechActive = true
    speechStartTime = Date()
    speechDetected = true
    silenceTimer?.invalidate()
    silenceTimer = nil
    silenceStartTime = nil
    onVoiceEvent?(.speechStarted)
}
```

### 3. Продолжение речи

**Условия:**
- `level > speechStartThreshold`
- `isSpeechActive` (речь активна)

**Действия:**
1. Отмена таймера тишины (если активен)
2. Сброс времени начала тишины
3. Сброс индикаторов таймера тишины

```swift
else if isAboveThreshold && isSpeechActive {
    if let timer = silenceTimer, timer.isValid {
        timer.invalidate()
        silenceTimer = nil
    }
    silenceStartTime = nil
    isSilenceTimerActive = false
    silenceTimerProgress = 0.0
    silenceTimerElapsed = 0.0
}
```

### 4. Детекция возможного окончания речи

**Условия:**
- `level <= speechStartThreshold`
- `isSpeechActive` (речь активна)
- Таймер тишины не активен

**Действия:**
1. Запуск таймера тишины для подтверждения окончания речи
2. Сохранение времени начала тишины
3. Установка флагов активности таймера

```swift
else if !isAboveThreshold && isSpeechActive {
    guard silenceTimer == nil || !silenceTimer!.isValid else {
        return
    }
    
    silenceTimer?.invalidate()
    silenceTimer = nil
    
    silenceStartTime = Date()
    isSilenceTimerActive = true
    silenceTimerProgress = 0.0
    silenceTimerElapsed = 0.0
    
    // Запуск таймера анимации прогресса
    silenceProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
        guard let self = self, let start = silenceStartValue else { return }
        let elapsed = Date().timeIntervalSince(start)
        let progress = min(1.0, elapsed / timeoutValue)
        
        MainActor.assumeIsolated {
            self.silenceTimerProgress = progress
            self.silenceTimerElapsed = elapsed
        }
        
        NotificationCenter.default.post(
            name: .silenceTimerUpdated,
            object: self,
            userInfo: [
                "progress": progress,
                "elapsed": elapsed,
                "timeout": timeoutValue
            ]
        )
    }
    
    // Основной таймер тишины
    silenceTimer = Timer.scheduledTimer(
        withTimeInterval: timeoutValue,
        repeats: false
    ) { [weak self] _ in
        MainActor.assumeIsolated {
            self?.handleSpeechEnd()
        }
    }
}
```

### 5. Подтверждение окончания речи

**Метод:** [`handleSpeechEnd()`](../../Data/Audio/VoiceDetector.swift:521)

**Условия:**
- `isSpeechActive` (речь активна)
- `speechStartTime` задано
- `recordingStartTime` задано
- Длительность речи >= `minSpeechDuration`

**Процесс:**

1. Вычисление длительности речи
2. Остановка индикаторов тишины
3. Проверка минимальной длительности
4. Обрезка аудиоданных до диапазона речи
5. Вычисление среднего уровня аудио
6. Валидация среднего уровня (`minSpeechLevel`)
7. Отправка события [`speechEnded`](../../Data/Audio/VoiceDetector.swift:23) с аудиоданными
8. Перезапуск записи для непрерывного прослушивания

```swift
let silenceStart = silenceStartTime ?? Date()
let duration = silenceStart.timeIntervalSince(startTime)

guard duration >= minSpeechDuration else {
    Logger.warning("VoiceDetector.speechTooShort()")
    isSpeechActive = false
    speechStartTime = nil
    return
}

// Обрезка аудиоданных
let startOffset = startTime.timeIntervalSince(recordingStart)
let speechDuration = duration

stopRecording()

if let originalData = audioBuffer {
    let trimmedData = try await trimWAVData(originalData, startOffset, speechDuration)
    
    // Валидация среднего уровня
    let avgLevel = calculateAverageLevel(from: trimmedData)
    if avgLevel < minSpeechLevel {
        Logger.warning("VoiceDetector.audioTooQuiet()")
        return
    }
    
    onVoiceEvent?(.speechEnded(trimmedData))
}

// Перезапуск записи
if isListening {
    startRecording()
    startLevelMonitoring()
}
```

## Валидация речи

### Минимальная длительность

**Параметр:** [`minSpeechDuration`](../../Data/Audio/VoiceDetector.swift:70)

**Значение:** 0.2 секунды (200 мс)

**Назначение:** Фильтрация коротких шумов, которые могут быть ошибочно приняты за речь

**Проверка:**
```swift
guard duration >= minSpeechDuration else {
    Logger.warning("VoiceDetector.speechTooShort() - Duration: \(duration)s < \(minSpeechDuration)s")
    return
}
```

### Минимальный уровень аудио

**Параметр:** [`minSpeechLevel`](../../Data/Audio/VoiceDetector.swift:73)

**Диапазон:** 0.01 - 0.1

**По умолчанию:** 0.04

**Назначение:** Фильтрация тихих шумов, которые могут быть ошибочно приняты за речь

**Вычисление среднего уровня:**

**Метод:** [`calculateAverageLevel(from:)`](../../Data/Audio/VoiceDetector.swift:496)

**Процесс:**
1. Пропуск WAV заголовка (44 байта)
2. Чтение сэмплов (Int16)
3. Вычисление суммы абсолютных значений
4. Нормализация в диапазон 0.0 - 1.0

```swift
func calculateAverageLevel(from data: Data) -> Float {
    guard data.count > 44 else { return 0.0 }
    
    let samplesData = data.dropFirst(44)
    let sampleCount = samplesData.count / 2
    guard sampleCount > 0 else { return 0.0 }
    
    var sum: Float = 0
    samplesData.withUnsafeBytes { rawBuffer in
        guard let buffer = rawBuffer.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
        for i in 0..<sampleCount {
            let sample = abs(Float(buffer[i]))
            sum += sample
        }
    }
    
    let average = sum / Float(sampleCount)
    return min(1.0, average / 32768.0)
}
```

**Валидация:**
```swift
let avgLevel = calculateAverageLevel(from: trimmedData)
if avgLevel < minSpeechLevel {
    Logger.warning("VoiceDetector.audioTooQuiet() - Avg level: \(avgLevel) < \(minSpeechLevel)")
    return  // Не отправлять событие
}
```

## Обрезка аудиоданных

### Метод trimWAVData

**Метод:** [`trimWAVData(_:startOffset:duration:)`](../../Data/Audio/VoiceDetector.swift:434)

**Параметры:**
- `data: Data` - Оригинальные аудиоданные
- `startOffset: TimeInterval` - Смещение начала речи
- `duration: TimeInterval` - Длительность речи

**Процесс:**

1. Создание временных файлов
2. Запись оригинальных данных
3. Создание `AVAsset` из файла
4. Создание `AVAssetExportSession` с preset `passthrough` (без перекодирования)
5. Установка временного диапазона
6. Экспорт обрезанных данных
7. Чтение обрезанных данных
8. Очистка временных файлов

**Формат аудио:**
- PCM 16-bit
- 16 kHz частота дискретизации
- Моно

**Байт в секунду:** 32000 байт/с (16 kHz * 2 байта * 1 канал)

## Управление детектором

### Начало прослушивания

**Метод:** [`startListening()`](../../Data/Audio/VoiceDetector.swift:179)

**Действия:**
1. Проверка флага `isListening`
2. Настройка аудио сессии
3. Установка `isListening = true`
4. Сброс флага паузы
5. Начало записи
6. Начало мониторинга уровня

```swift
func startListening() {
    guard !isListening else { return }
    
    Logger.voice("VoiceDetector.startListening()")
    isListening = true
    isPaused = false
    
    startRecording()
    startLevelMonitoring()
}
```

### Остановка прослушивания

**Метод:** [`stopListening()`](../../Data/Audio/VoiceDetector.swift:192)

**Действия:**
1. Логирование остановки
2. Установка `isListening = false`
3. Установка флага паузы
4. Отмена таймера тишины
5. Остановка записи
6. Остановка мониторинга уровня

```swift
func stopListening() {
    Logger.voice("VoiceDetector.stopListening()")
    isListening = false
    isPaused = true
    
    silenceTimer?.invalidate()
    silenceTimer = nil
    silenceProgressTimer?.invalidate()
    silenceProgressTimer = nil
    
    stopRecording()
    stopLevelMonitoring()
}
```

### Приостановка прослушивания

**Метод:** [`pauseListening()`](../../Data/Audio/VoiceDetector.swift:207)

**Действия:**
1. Логирование паузы
2. Установка флага паузы
3. Остановка мониторинга уровня

```swift
func pauseListening() {
    Logger.voice("VoiceDetector.pauseListening()")
    isPaused = true
    stopLevelMonitoring()
}
```

### Возобновление прослушивания

**Метод:** [`resumeListening()`](../../Data/Audio/VoiceDetector.swift:214)

**Действия:**
1. Логирование возобновления
2. Сброс флага паузы
3. Начало мониторинга уровня

```swift
func resumeListening() {
    Logger.voice("VoiceDetector.resumeListening()")
    isPaused = false
    startLevelMonitoring()
}
```

### Обновление параметров

#### Обновление порога начала речи

**Метод:** [`updateThreshold(_:)`](../../Data/Audio/VoiceDetector.swift:170)

**Параметры:**
- `threshold: Float` - Новый порог

**Действия:**
1. Обновление `speechStartThreshold`
2. Логирование изменения

```swift
func updateThreshold(_ threshold: Float) {
    speechStartThreshold = threshold
}
```

#### Обновление тайм-аута тишины

**Метод:** [`updateSilenceTimeout(_:)`](../../Data/Audio/VoiceDetector.swift:175)

**Параметры:**
- `timeout: Double` - Новый тайм-аут

**Действия:**
1. Обновление `silenceTimeout`
2. Логирование изменения

```swift
func updateSilenceTimeout(_ timeout: Double) {
    self.silenceTimeout = timeout
}
```

#### Обновление минимального уровня речи

**Метод:** [`updateMinSpeechLevel(_:)`](../../Data/Audio/VoiceDetector.swift:180)

**Параметры:**
- `level: Float` - Новый минимальный уровень

**Действия:**
1. Обновление `minSpeechLevel`
2. Логирование изменения

```swift
func updateMinSpeechLevel(_ level: Float) {
    self.minSpeechLevel = level
    Logger.voice("VoiceDetector.minSpeechLevel updated to: \(level)")
}
```

## Поток детекции речи

```mermaid
sequenceDiagram
    participant User as Пользователь
    participant VD as VoiceDetector
    participant AR as AVAudioRecorder
    participant UI as UI
    
    User->>VD: startListening()
    VD->>AR: startRecording()
    VD->>VD: startLevelMonitoring()
    
    loop Каждые 0.05 сек
        AR->>VD: updateMeters()
        VD->>VD: checkAudioLevel()
        
        alt Уровень > порог и речь не активна
            VD->>VD: speechStarted()
            VD->>UI: audioLevel
            VD->>UI: speechDetected = true
        else Уровень > порог и речь активна
            VD->>VD: Продолжение речи
        else Уровень < порог и речь активна
            VD->>VD: Запуск таймера тишины
            VD->>UI: isSilenceTimerActive = true
            VD->>UI: silenceTimerProgress
        end
    end
    
    alt Таймер тишины истек
        VD->>VD: handleSpeechEnd()
        VD->>VD: stopRecording()
        VD->>VD: trimWAVData()
        VD->>VD: calculateAverageLevel()
        
        avgLevel >= minSpeechLevel?
        alt Да
            VD->>UI: speechEnded(data)
        else Нет
            VD->>VD: Отклонить тихий шум
        end
        
        VD->>AR: startRecording()
        VD->>VD: startLevelMonitoring()
    end
    
    User->>VD: stopListening()
    VD->>AR: stopRecording()
    VD->>VD: stopLevelMonitoring()
```

## Уведомления

### Silence Timer Updated

**Имя:** `.silenceTimerUpdated`

**Описание:** Уведомление об обновлении прогресса таймера тишины.

**Отправитель:** [`VoiceDetector`](../../Data/Audio/VoiceDetector.swift:35)

**UserInfo:**

| Ключ | Тип | Описание |
|-------|------|-----------|
| `progress` | `Double` | Прогресс таймера (0.0 - 1.0) |
| `elapsed` | `Double` | Прошедшее время (секунды) |
| `timeout` | `Double` | Тайм-аут (секунды) |

### Silence Timer Reset

**Имя:** `.silenceTimerReset`

**Описание:** Уведомление о сбросе таймера тишины.

**Отправитель:** [`VoiceDetector`](../../Data/Audio/VoiceDetector.swift:35)

## Связанные файлы

- [`VoiceDetector.swift`](../../Data/Audio/VoiceDetector.swift:35) - Детектор голосовой активности
- [`FullDuplexAudioManager.swift`](../../Data/Audio/FullDuplexAudioManager.swift:24) - Менеджер полнодуплексного аудио
- [`Settings.swift`](Settings.swift:10) - Модель настроек аудио
- [`DM_AUDIO.md`](DM_AUDIO.md) - Документация аудио системы
