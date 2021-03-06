public class OavpAnalysis {
  private FFT fft;
  private AudioPlayer player;
  private AudioInput input;
  private AudioSample track;
  private BeatDetect beat;
  private PrintWriter deepAnalysisWriter;

  private HashMap<Float, List<String>> midiData;
  List<Float> midiDataMsKeys;
  Set<Integer> midiNotesUsed;

  private HashMap<Integer, OavpEvent> oavpEvents;

  private int avgSize;
  private int bufferSize;
  private float sampleRate;
  private float spectrumSmoothing;
  private float bufferSmoothing;
  private float levelSmoothing;
  private String seperator;
  private boolean isBeatOnset;
  private boolean isQuantizedOnset;

  private float[] spectrum;
  private float[] lastSpectrum;
  private float[] spectrumChunkAvgs;
  private float minSpectrumVal = 0.0f;
  private float maxSpectrumVal = 0.0f;

  private int spectrumChunkCount = 5;

  private float[] leftBuffer;
  private float[] lastLeftBuffer;
  private float[] rightBuffer;
  private float[] lastRightBuffer;
  private float[] leftSamples;
  private float[] rightSamples;

  private float leftLevel;
  private float lastLeftLevel = 0.0f;
  private float minLeftLevel = 0.0f;
  private float maxLeftLevel = 0.0f;

  private float rightLevel;
  private float lastRightLevel;
  private float minRightLevel = 0.0f;
  private float maxRightLevel = 0.0f;

  private boolean firstMinDone = true;
  private boolean useDB = true;
  private boolean isLineIn;

  OavpAnalysis (Minim minim, OavpConfig config) {
    beat = new BeatDetect();
    beat.setSensitivity(300);
    oavpEvents = new HashMap<Integer, OavpEvent>();
    if (config.AUDIO_FILE != null && config.AUDIO_FILE != "") {
      if (config.ANALYZE_AUDIO) {
        println("[ oavp ] Analyzing audio file: " + config.AUDIO_FILE);
        deepAnalysisWriter = createWriter(dataPath(config.AUDIO_FILE + ".deep-analysis.txt"));
        seperator = config.AUDIO_ANALYSIS_SEPERATOR;
        bufferSize = config.BUFFER_SIZE;
        track = minim.loadSample(config.AUDIO_FILE, bufferSize * 2);
        sampleRate = track.sampleRate();
        leftSamples = track.getChannel(AudioSample.LEFT);
        rightSamples = track.getChannel(AudioSample.RIGHT);
        fft = new FFT(bufferSize, sampleRate);
        fft.logAverages(config.MIN_BANDWIDTH_PER_OCTAVE, config.BANDS_PER_OCTAVE);
        avgSize = fft.avgSize();
        lastLeftBuffer = new float[bufferSize];
        lastRightBuffer = new float[bufferSize];
        lastSpectrum = new float[avgSize];
        java.util.Arrays.fill(lastLeftBuffer, 0.0);
        java.util.Arrays.fill(lastRightBuffer, 0.0);
        java.util.Arrays.fill(lastSpectrum, 0.0);
      } else if (config.ENABLE_VIDEO_RENDER) {
        println("[ oavp ] Rendering movie...");
      } else {
        println("[ oavp ] Loading audio file: " + config.AUDIO_FILE);
        player = minim.loadFile(config.AUDIO_FILE, config.BUFFER_SIZE);
        player.loop();
        isLineIn = false;
        fft = new FFT(player.bufferSize(), player.sampleRate());
        fft.logAverages(config.MIN_BANDWIDTH_PER_OCTAVE, config.BANDS_PER_OCTAVE);
        avgSize = fft.avgSize();
        bufferSize = player.bufferSize();
      }
    } else {
      input = minim.getLineIn();
      isLineIn = true;
      fft = new FFT(input.bufferSize(), input.sampleRate());
      fft.logAverages(config.MIN_BANDWIDTH_PER_OCTAVE, config.BANDS_PER_OCTAVE);
      avgSize = fft.avgSize();
      bufferSize = input.bufferSize();
    }
    spectrum = new float[avgSize];
    spectrumChunkAvgs = new float[spectrumChunkCount];
    leftBuffer = new float[bufferSize];
    rightBuffer = new float[bufferSize];

    spectrumSmoothing = config.SPECTRUM_SMOOTHING;
    bufferSmoothing = config.BUFFER_SMOOTHING;
    levelSmoothing = config.LEVEL_SMOOTHING;
  }

  /**
   * Pause/play any queued audio track
   * @return none
   */
  public void toggleLoop() {
    if (!isLineIn) {
      if (player.isPlaying()) {
        player.pause();
      } else {
        player.loop();
      }
    }
  }

  /**
   * Get the logarithmic dB value of x
   * @param x the input value
   */
  private float dB(float x) {
    if (x == 0) {
      return 0;
    }
    else {
      return 10 * (float)Math.log10(x);
    }
  }

  /**
   * Run beat detection algorithm
   * @return none
   */
  private void detectBeat() {
    if (isLineIn) {
      beat.detect(input.mix);
    } else {
      beat.detect(player.mix);
    }
    isBeatOnset = beat.isOnset();
  }

  /**
   * Get current left channel audio level
   * @return the left level value
   */
  public float getCurrLeftLevel() {
    if (isLineIn) {
      return input.left.level();
    }
    return player.left.level();
  }

  /**
   * Get current right channel audio level
   * @return the right level value
   */
  public float getCurrRightLevel() {
    if (isLineIn) {
      return input.right.level();
    }
    return player.right.level();
  }

  /**
   * Get current ith value in left channel buffer
   * @param i the index
   * @return the current ith value in left channel buffer
   */
  public float getCurrLeftBuffer(int i) {
    if (isLineIn) {
      return input.left.get(i);
    }
    return player.left.get(i);
  }

  /**
   * Get current ith value in right channel buffer
   * @param i the index
   * @return the current ith value in right channel buffer
   */
  public float getCurrRightBuffer(int i) {
    if (isLineIn) {
      return input.right.get(i);
    }
    return player.right.get(i);
  }

  /**
   * Apply fast-fourier transform on currently active mix
   */
  private void forwardMix() {
    if (isLineIn) {
      fft.forward( input.mix );
    } else {
      fft.forward( player.mix );
    }
  }

  /**
   * Apply fast-fourier transform and spectrum smoothing on audio
   */
  public void forward() {
    detectBeat();

    // Adjust smoothing on left level
    float currLeftLevel;
    currLeftLevel = getCurrLeftLevel();

    // Smooth using exponential moving average
    leftLevel = (levelSmoothing) * leftLevel + ((1 - levelSmoothing) * currLeftLevel);

    // Find max and min values ever displayed across whole spectrum
    if (currLeftLevel > maxLeftLevel) {
      maxLeftLevel = currLeftLevel;
    }
    if (!firstMinDone || (currLeftLevel < minLeftLevel)) {
      minLeftLevel = leftLevel;
    }

    // Adjust smoothing on right level
    float currRightLevel;
    currRightLevel = getCurrRightLevel();

    // Smooth using exponential moving average
    rightLevel = (levelSmoothing) * rightLevel + ((1 - levelSmoothing) * currRightLevel);

    // Find max and min values ever displayed across whole spectrum
    if (currRightLevel > maxRightLevel) {
      maxRightLevel = currRightLevel;
    }
    if (!firstMinDone || (currRightLevel < minRightLevel)) {
      minRightLevel = rightLevel;
    }

    // Adjust smoothing on buffer
    for (int i = 0; i < getBufferSize(); i++) {
      float currLeftBuffer;
      float currRightBuffer;
      currLeftBuffer = getCurrLeftBuffer(i);
      currRightBuffer = getCurrRightBuffer(i);
      leftBuffer[i] = (bufferSmoothing) * leftBuffer[i] + ((1 - bufferSmoothing) * currLeftBuffer);
      rightBuffer[i] = (bufferSmoothing) * rightBuffer[i] + ((1 - bufferSmoothing) * currRightBuffer);
    }

    forwardMix();

    // Adjust smoothing on spectrum values
    for (int i = 0; i < avgSize; i++) {
      // Get spectrum value (using dB conversion or not, as desired)
      float currSpectrumVal;
      if (useDB) {
        currSpectrumVal = dB(fft.getAvg(i));
      }
      else {
        currSpectrumVal = fft.getAvg(i);
      }

      // Smooth using exponential moving average
      spectrum[i] = (spectrumSmoothing) * spectrum[i] + ((1 - spectrumSmoothing) * currSpectrumVal);

      // Find max and min values ever displayed across whole spectrum
      if (spectrum[i] > maxSpectrumVal) {
        maxSpectrumVal = spectrum[i];
      }
      if (!firstMinDone || (spectrum[i] < minSpectrumVal)) {
        minSpectrumVal = spectrum[i];
      }
    }

    int spectrumChunkSize = floor(spectrum.length / 4);
    int spectrumChunkIndex = 0;
    for (int i = 0; i < spectrum.length; i += spectrumChunkSize) {
      spectrumChunkAvgs[spectrumChunkIndex] = arrayAverage(Arrays.copyOfRange(spectrum, i, Math.min(spectrum.length, i + spectrumChunkSize)));
      spectrumChunkIndex += 1;
    }
  }

  /**
   * Get spectrum values
   * @return array of float values for spectrum
   */
  public float[] getSpectrum() {
    return spectrum;
  }

  public float getSpectrumChunkAvg(int index) {
    return spectrumChunkAvgs[index];
  }

  /**
   * Get left channel buffer
   * @return array of float values for left buffer
   */
  public float[] getLeftBuffer() {
    return leftBuffer;
  }

  /**
   * Get right channel buffer
   * @return array of float values for right buffer
   */
  public float[] getRightBuffer() {
    return rightBuffer;
  }

  /**
   * Get ith spectrum value
   * @param i the index
   * @return the ith spectrum value
   */
  public float getSpectrumVal(int i) {
    return spectrum[i];
  }

  /**
   * Get ith left buffer value
   * @param i the index
   * @return the ith left buffer value
   */
  public float getLeftBuffer(int i) {
    return leftBuffer[i];
  }

  /**
   * Get ith right buffer value
   * @param i the index
   * @return the ith right buffer value
   */
  public float getRightBuffer(int i) {
    return rightBuffer[i];
  }

  /**
   * Get left channel level
   * @return the left channel level
   */
  public float getLeftLevel() {
    return leftLevel;
  }

  /**
   * Get right channel level
   * @return the right channel level
   */
  public float getRightLevel() {
    return rightLevel;
  }

  /**
   * Get the scaled average left/right channel level
   * @return the scaled average left/right channel level
   */
  public float getLevel() {
    return (scaleLeftLevel(leftLevel) + scaleRightLevel(rightLevel)) / 2;
  }

  /**
   * Get the current active input buffer size
   * @return the current active input buffer size
   */
  public int getBufferSize() {
    if (isLineIn) {
      return input.bufferSize();
    }
    return bufferSize;
  }

  /**
   * Get the current averaging size
   * @return the current averaging size
   */
  public int getAvgSize() {
    return avgSize;
  }

  /**
   * Get the max spectrum value
   * @return the max spectrum value
   */
  public float getMaxSpectrumVal() {
    return maxSpectrumVal;
  }

  /**
   * Get the min spectrum value
   * @return the min spectrum value
   */
  public float getMinSpectrumVal() {
    return minSpectrumVal;
  }

  /**
   * Get the scaled input spectrum value
   * @param x the input spectrum value
   * @return the scaled input spectrum value
   */
  public float scaleSpectrumVal(float x) {
    float scaleFactor = (maxSpectrumVal - minSpectrumVal) + 0.00001f;
    return (x - minSpectrumVal) / scaleFactor;
  }

  /**
   * Get the scaled input left level
   * @param x the input left level
   * @return the scaled input left level
   */
  public float scaleLeftLevel(float x) {
    float scaleFactor = (maxLeftLevel - minLeftLevel) + 0.00001f;
    return (x - minLeftLevel) / scaleFactor;
  }

  /**
   * Get the scaled input right level
   * @param x the input right level
   * @return the scaled input right level
   */
  public float scaleRightLevel(float x) {
    float scaleFactor = (maxRightLevel - minRightLevel) + 0.00001f;
    return (x - minRightLevel) / scaleFactor;
  }

  /**
   * Toggle decible usage
   */
  public void toggleUseDB() {
    useDB = !useDB;
  }

  /**
   * Toggle first min done
   */
  public void toggleFirstMinDone() {
    firstMinDone = !firstMinDone;
  }

  /**
   * Set spectrum smoothing value
   * @param newSmoothing the smoothing value
   */
  public void setSpectrumSmoothing(float newSmoothing) {
    spectrumSmoothing = newSmoothing;
  }

  /**
   * Set level smoothing value
   * @param newSmoothing the smoothing value
   */
  public void setLevelSmoothing(float newSmoothing) {
    levelSmoothing = newSmoothing;
  }

  /**
   * Set buffer smoothing value
   * @param newSmoothing the smoothing value
   */
  public void setBufferSmoothing(float newSmoothing) {
    bufferSmoothing = newSmoothing;
  }

  /**
   * Check if current slice is a beat onset
   */
  public boolean isBeatOnset() {
    return isBeatOnset;
  }

  public boolean isQuantizedOnset() {
    return isQuantizedOnset;
  }

  public float getRootMeanSquare(float values[]) {
    int n = values.length;
    float squareSum = 0;

    for (int i = 0; i < values.length; i++) {
      squareSum += Math.pow(values[i], 2);
    }

    return (float) Math.sqrt(squareSum / n);
  }

  public void analyzeAudioFile(OavpConfig config) {
    println("[ oavp ] Audio Analysis - bufferSize: " + bufferSize);
    println("[ oavp ] Audio Analysis - sampleRate: " + sampleRate);

    float[] buffer = new float[bufferSize];
    leftBuffer = new float[bufferSize];
    rightBuffer = new float[bufferSize];

    println("[ oavp ] Audio Analysis - buffer length: " + buffer.length);
    println("[ oavp ] Audio Analysis - samples length: " + leftSamples.length);
    println("[ oavp ] Audio Analysis - logAverages minBandwidth: 22, bandsPerOctave: 3");
    println("[ oavp ] Audio Analysis - beat detect sensitivity: 10");

    int totalChunks = (leftSamples.length / bufferSize) + 1;

    println("[ oavp ] Audio Analysis - total chunks: " + totalChunks);
    println("[ oavp ] Audio Analysis - track length (ms): " + track.length());
    println("[ oavp ] Audio Analysis - avgSize (number of FFT slices) " + avgSize);

    float quantizationIntervalMs = (60000 / float(config.TARGET_BPM)) / config.QUANTIZATION;

    int audioLengthMs = track.length();
    float timeRemainder = audioLengthMs % quantizationIntervalMs;
    float timeQuotient = (audioLengthMs - timeRemainder) / quantizationIntervalMs;

    List<Float> quantizationMarkers = new ArrayList();

    for (int i = 0; i < int(timeQuotient); i++) {
      quantizationMarkers.add(i * quantizationIntervalMs);
    }

    println("[ oavp ] Audio Analysis - Total Beat Markers: " + quantizationMarkers.size());

    if (config.MIDI_FILE != null && config.MIDI_FILE != "") {
      println("[ oavp ] Audio Analysis - Parsing Midi File");
      File midiFile = new File(dataPath(config.MIDI_FILE));
      midiData = new HashMap<Float, List<String>>();
      midiDataMsKeys = new ArrayList<Float>();
      midiNotesUsed = new HashSet<Integer>();
      try {
        Sequence seq = MidiSystem.getSequence(midiFile);
        Track[] midiTracks = seq.getTracks();
        int ppq = seq.getResolution();
        Track midiTrack = midiTracks[0];

        for (int i = 0; i < midiTrack.size(); i++) {
          MidiEvent midiEvent = midiTrack.get(i);
          long tick = midiEvent.getTick();

          int msPerTick = (60000 / (config.TARGET_BPM * ppq));
          float ms = tick * msPerTick;

          if (midiEvent.getMessage() instanceof ShortMessage) {
            ShortMessage shortMessage = (ShortMessage) midiEvent.getMessage();
            int command = shortMessage.getCommand();
            if (command == ShortMessage.NOTE_OFF || command == ShortMessage.NOTE_ON) {
              String midiEntry = shortMessage.getData1() + "-" + (command == ShortMessage.NOTE_ON ? 1 : 0) + "-" + shortMessage.getData2();
              midiNotesUsed.add(shortMessage.getData1());
              if (midiData.containsKey(ms)) {
                midiData.get(ms).add(midiEntry);
              } else {
                List<String> midiEntries = new ArrayList<String>();
                midiEntries.add(midiEntry);
                midiData.put(ms, midiEntries);
                midiDataMsKeys.add(ms);
              }
            }
          }
        }
      } catch(Exception e) {
        e.printStackTrace();
        exit();
      }

      println("[ oavp ] Audio Analysis - MIDI Notes Used: " + midiNotesUsed);
    }

    for (int chunkIndex = 0; chunkIndex < totalChunks; ++chunkIndex) {
      int chunkStartIndex = chunkIndex * bufferSize;
      int chunkSize = min(leftSamples.length - chunkStartIndex, bufferSize);

      // Copy the chunks into respective buffers
      System.arraycopy(leftSamples, chunkStartIndex, leftBuffer, 0, chunkSize);
      System.arraycopy(rightSamples, chunkStartIndex, rightBuffer, 0, chunkSize);

      // LEFT BUFFER DEFAULT FOR FFT
      buffer = leftBuffer;

      // If we don't have any samples left, fill the remaining with 0
      if ( chunkSize < bufferSize ) {
        java.util.Arrays.fill( buffer, chunkSize, buffer.length - 1, 0.0 );
      }

      // Push buffer into fft.forward to get our fast fourier transform
      fft.forward( buffer );
      beat.detect( buffer );
      leftLevel = getRootMeanSquare(leftBuffer);
      rightLevel = getRootMeanSquare(rightBuffer);

      // Apply smoothing and averages
      float currLeftLevel;
      currLeftLevel = leftLevel;
      leftLevel = (levelSmoothing) * lastLeftLevel + ((1 - levelSmoothing) * currLeftLevel);
      if (currLeftLevel > maxLeftLevel) {
        maxLeftLevel = currLeftLevel;
      }
      if (!firstMinDone || (currLeftLevel < minLeftLevel)) {
        minLeftLevel = leftLevel;
      }

      float currRightLevel;
      currRightLevel = rightLevel;
      rightLevel = (levelSmoothing) * lastRightLevel + ((1 - levelSmoothing) * currRightLevel);
      if (currRightLevel > maxRightLevel) {
        maxRightLevel = currRightLevel;
      }
      if (!firstMinDone || (currRightLevel < minRightLevel)) {
        minRightLevel = rightLevel;
      }

      for (int i = 0; i < bufferSize; i++) {
        float currLeftBuffer;
        float currRightBuffer;
        currLeftBuffer = leftBuffer[i];
        currRightBuffer = rightBuffer[i];
        leftBuffer[i] = (bufferSmoothing) * lastLeftBuffer[i] + ((1 - bufferSmoothing) * currLeftBuffer);
        rightBuffer[i] = (bufferSmoothing) * lastRightBuffer[i] + ((1 - bufferSmoothing) * currRightBuffer);
      }

      for (int i = 0; i < avgSize; i++) {
        float currSpectrumVal;
        if (useDB) {
          currSpectrumVal = dB(fft.getAvg(i));
        }
        else {
          currSpectrumVal = fft.getAvg(i);
        }
        spectrum[i] = (spectrumSmoothing) * lastSpectrum[i] + ((1 - spectrumSmoothing) * currSpectrumVal);
        if (spectrum[i] > maxSpectrumVal) {
          maxSpectrumVal = spectrum[i];
        }
        if (!firstMinDone || (spectrum[i] < minSpectrumVal)) {
          minSpectrumVal = spectrum[i];
        }
      }

      // Store last buffer values (for next smoothing)
      lastLeftLevel = leftLevel;
      lastRightLevel = rightLevel;
      System.arraycopy(leftBuffer, 0, lastLeftBuffer, 0, bufferSize);
      System.arraycopy(rightBuffer, 0, lastRightBuffer, 0, bufferSize);
      System.arraycopy(spectrum, 0, lastSpectrum, 0, avgSize);

      // Append TIME
      float timeValue = chunkStartIndex / sampleRate;

      StringBuilder deepAnalysisMsg = new StringBuilder(nf(timeValue, 0, 3).replace(',', '.'));

      // Append Left Level & Right Level
      deepAnalysisMsg.append(seperator + nf(leftLevel, 0, config.ANALYSIS_PRECISION).replace(',', '.'));
      deepAnalysisMsg.append(seperator + nf(rightLevel, 0, config.ANALYSIS_PRECISION).replace(',', '.'));

      // Append Left Buffer & Right Buffer
      for (int i=0; i < bufferSize; ++i) {
        deepAnalysisMsg.append(seperator + nf(leftBuffer[i], 0, config.ANALYSIS_PRECISION).replace(',', '.'));
      }
      for (int i=0; i < bufferSize; ++i) {
        deepAnalysisMsg.append(seperator + nf(rightBuffer[i], 0, config.ANALYSIS_PRECISION).replace(',', '.'));
      }

      // Append Spectrum (non avged)
      for (int i=0; i < avgSize; ++i) {
        deepAnalysisMsg.append(seperator + nf(spectrum[i], 0, config.ANALYSIS_PRECISION).replace(',', '.'));
      }

      // Append Events
      deepAnalysisMsg.append(seperator);

      if (beat.isOnset()) {
        deepAnalysisMsg.append(config.DEFAULT_EVENTS.BEAT + "-1-100" + config.EVENTS_SEPERATOR);
      }

      float timeValueMs = timeValue * 1000;

      if (quantizationMarkers.size() > 0) {
        float quantizationMarkerMs = quantizationMarkers.get(0);
        float timeDifference = abs(timeValueMs - quantizationMarkerMs);

        if (timeDifference <= 10 || timeValueMs > quantizationMarkerMs) {
          quantizationMarkers.remove(0);
          deepAnalysisMsg.append(config.DEFAULT_EVENTS.QUANTIZATION_MARKER + "-1-100" + config.EVENTS_SEPERATOR);
        }
      }

      if (config.MIDI_FILE != null) {
        if (midiDataMsKeys.size() > 0) {
          float midiDataMsKey = midiDataMsKeys.get(0);
          float timeDifference = abs(timeValueMs - midiDataMsKey);

          if (timeDifference <= 10 || timeValueMs > midiDataMsKey) {
            midiDataMsKeys.remove(0);

            List<String> midiDataEntry = (List) midiData.get(midiDataMsKey);
            String encodedMidiEvent = String.join(config.EVENTS_SEPERATOR, midiDataEntry);

            deepAnalysisMsg.append(encodedMidiEvent);
          }
        }
      }

      deepAnalysisWriter.println(deepAnalysisMsg.toString());
    }
    track.close();
    deepAnalysisWriter.flush();
    deepAnalysisWriter.close();
    println("[ oavp ] Audio file analysis done.");
  }

  public void readAnalysis(OavpConfig config, float[] analysisData, String[] eventsData) {
    parseAnalysisData(analysisData, config);
    parseEvents(eventsData);
    parseDefaultEvents(config);
  }

  private void parseAnalysisData(float[] analysisData, OavpConfig config) {
    leftLevel = analysisData[config.ANALYSIS_LEFT_LEVEL_INDEX];
    rightLevel = analysisData[config.ANALYSIS_RIGHT_LEVEL_INDEX];
    System.arraycopy(analysisData, config.ANALYSIS_INDEX, leftBuffer, 0, bufferSize);
    System.arraycopy(analysisData, config.ANALYSIS_INDEX + bufferSize, rightBuffer, 0, bufferSize);
    System.arraycopy(analysisData, config.ANALYSIS_INDEX + bufferSize + bufferSize, spectrum, 0, avgSize);
  }

  private void parseEvents(String[] eventsData) {
    oavpEvents.clear();
    for (int i = 0; i < eventsData.length; i++) {
      if (eventsData[i].length() > 0) {
        OavpEvent event = new OavpEvent(eventsData[i]);
        oavpEvents.put(event.getNote(), event);
      }
    }
  }

  private void parseDefaultEvents(OavpConfig config) {
    isBeatOnset = false;
    isQuantizedOnset = false;

    if (oavpEvents.containsKey(config.DEFAULT_EVENTS.BEAT)) {
      isBeatOnset = true;
    }
    if (oavpEvents.containsKey(config.DEFAULT_EVENTS.QUANTIZATION_MARKER)) {
      isQuantizedOnset = true;
    }
  }

  public boolean isEventOn(int note) {
    if (oavpEvents.containsKey(note) && oavpEvents.get(note).isOn()) {
      return true;
    }
    return false;
  }

  public boolean isEventOff(int note) {
    if (oavpEvents.containsKey(note) && oavpEvents.get(note).isOff()) {
      return true;
    }
    return false;
  }

  public OavpEvent getEvent(int note) {
    return oavpEvents.get(note);
  }
}

public class OavpEvent {
  private int note;
  private boolean state;
  private int velocity;

  OavpEvent(String eventData) {
    String[] eventDataSplit = eventData.split("-");
    this.note = int(eventDataSplit[0]);
    this.state = int(eventDataSplit[1]) == 1;
    this.velocity = int(eventDataSplit[2]);
  }

  public int getNote() {
    return this.note;
  }

  public int getVelocity() {
    return this.velocity;
  }

  public boolean getState() {
    return this.state;
  }

  public boolean isOn() {
    return this.state == true;
  }

  public boolean isOff() {
    return this.state == false;
  }
}