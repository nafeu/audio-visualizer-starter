public class OavpPulser {
  private float value = 0;
  private float duration = 1;
  private Easing easing = Ani.LINEAR;
  private Ani ani;

  OavpPulser() {}

  public OavpPulser duration(float duration) {
    this.duration = duration;
    return this;
  }

  public OavpPulser easing(Easing easing) {
    this.easing = easing;
    return this;
  }

  public float getValue() {
    return value;
  }

  public void pulse() {
    value = 1;
    ani = Ani.to(this, duration, "value", 0, easing);
  }

  public void pulseIf(boolean trigger) {
    if (trigger) {
      pulse();
    }
  }
}

public class OavpInterval {
  private float[][] intervalData;
  private int storageSize;
  private int snapshotSize;
  private int frameDelayCount = 0;
  private int delay = 1;
  private float averageWeight = 1;

  OavpInterval(int storageSize, int snapshotSize) {
    this.storageSize = storageSize;
    this.snapshotSize = snapshotSize;
    intervalData = new float[storageSize][snapshotSize];
  }

  public OavpInterval delay(int delay) {
    this.delay = delay;
    return this;
  }

  public OavpInterval averageWeight(float averageWeight) {
    this.averageWeight = averageWeight;
    return this;
  }

  public void update(float[] snapshot) {
    if (frameDelayCount == delay) {
      float[][] temp = new float[storageSize][snapshotSize];
      for (int i = 1; i < storageSize; i++) {
        temp[i] = intervalData[i - 1];
      }
      for (int j = 0; j < snapshotSize; j++) {
        temp[0][j] = snapshot[j];
      }
      intervalData = temp;
      frameDelayCount = 0;
    } else {
      frameDelayCount++;
    }
  }

  public void update(float snapshot) {
    if (frameDelayCount == delay) {
      float[][] temp = new float[storageSize][snapshotSize];
      for (int i = 1; i < storageSize; i++) {
        temp[i] = intervalData[i - 1];
      }
      temp[0][0] = average(snapshot, temp[1][0], averageWeight);
      intervalData = temp;
      frameDelayCount = 0;
    } else {
      frameDelayCount++;
    }
  }

  public void update(boolean rawSnapshot) {
    float snapshot;
    if (rawSnapshot) {
      snapshot = 1.0;
    } else {
      snapshot = 0.0;
    }
    if (frameDelayCount == delay) {
      float[][] temp = new float[storageSize][snapshotSize];
      for (int i = 1; i < storageSize; i++) {
        temp[i] = intervalData[i - 1];
      }
      temp[0][0] = snapshot;
      intervalData = temp;
      frameDelayCount = 0;
    } else {
      frameDelayCount++;
    }
  }

  public float[] getIntervalData(int i) {
    return intervalData[i];
  }

  public int getIntervalSize() {
    return intervalData.length;
  }

  private float average(float a, float b, float weight) {
    return (a + (weight * b)) / (1 + weight);
  }

  private float average(float a, float b) {
    return (a + b) / 2;
  }
}

public class OavpGridInterval {
  private float[][] data;
  private int numRows;
  private int numCols;
  private int frameDelayCount = 0;
  private int delay = 1;
  private float averageWeight = 1;

  OavpGridInterval(int numRows, int numCols) {
    this.numRows = numRows;
    this.numCols = numCols;
    data = new float[numRows][numCols];
  }

  public OavpGridInterval delay(int delay) {
    this.delay = delay;
    return this;
  }

  public OavpGridInterval averageWeight(float averageWeight) {
    this.averageWeight = averageWeight;
    return this;
  }

  public void update(float value) {
    if (frameDelayCount == delay) {
      float[][] temp = new float[numRows][numCols];
      for (int i = 0; i < numRows; i++) {
        for (int j = 0; j < numCols; j++) {
          if (i == 0 && j == 0) {
            temp[i][j] = average(value, data[i][j + 1], averageWeight);
          }
          else if (j == 0) {
            temp[i][j] = data[i - 1][numCols - 1];
          }
          else {
            temp[i][j] = data[i][j - 1];
          }
        }
      }
      data = temp;
      frameDelayCount = 0;
    } else {
      frameDelayCount++;
    }
  }

  public void updateDiagonal(float value) {
    if (frameDelayCount == delay) {
      float[][] temp = new float[numRows][numCols];
      for (int i = 0; i < numRows; i++) {
        for (int j = 0; j < numCols; j++) {
          if (i == 0 && j == 0) {
            temp[i][j] = average(value, data[i][j + 1], averageWeight);
          }
          else {
            if (i < j) {
              temp[i][j] = data[i][j - 1];
            } else if (i > j) {
              temp[i][j] = data[i - 1][j];
            } else {
              // This one can be in either direction
              temp[i][j] = data[i][j - 1];
            }
          }
        }
      }
      data = temp;
      frameDelayCount = 0;
    } else {
      frameDelayCount++;
    }
  }

  public void updateDimensional(float value) {
    if (frameDelayCount == delay) {
      float[][] temp = new float[numRows][numCols];
      for (int i = 0; i < numRows; i++) {
        for (int j = 0; j < numCols; j++) {
          if (j == 0) {
            temp[i][j] = average(value, data[i][j], averageWeight);
          } else {
            temp[i][j] = data[i][j - 1];
          }
        }
      }
      data = temp;
      frameDelayCount = 0;
    } else {
      frameDelayCount++;
    }
  }

  public float getData(int i, int j) {
    return data[i][j];
  }

  public int getNumCols() {
    return numCols;
  }

  public int getNumRows() {
    return numRows;
  }

  private float average(float a, float b, float weight) {
    return (a + (weight * b)) / (1 + weight);
  }
}

public class OavpEmission {
  public float value = 0;
  private final float target = 1;
  public float[] payload;
  public boolean isDead = false;

  OavpEmission(float duration, Easing easing) {
    start(duration, easing);
  }

  OavpEmission(float duration, Easing easing, float[] payload) {
    this.payload = payload;
    start(duration, easing);
  }

  private void start(float duration, Easing easing) {
    Ani.to(this, duration, "value", target, easing);
  }

  public void update() {
    if (value == target) {
      isDead = true;
    }
  }
}

public class OavpRhythm {
  private AudioOutput out;
  private BeatDetect beat;
  private boolean isPlaying;
  private float tempo = 60;
  private float rhythm = 1;
  private int limit = 1000;
  private int sensitivity = 100;
  private Minim minim;

  OavpRhythm(Minim minim) {
    this.minim = minim;
    this.rhythm = rhythm;
    beat = new BeatDetect();
    beat.setSensitivity(sensitivity);
  }

  public OavpRhythm duration(float duration) {
    this.tempo = 60 / duration;
    return this;
  }

  public OavpRhythm tempo(float tempo) {
    this.tempo = tempo;
    return this;
  }

  public OavpRhythm rhythm(float rhythm) {
    this.rhythm = rhythm;
    return this;
  }

  public OavpRhythm limit(int limit) {
    this.limit = limit;
    return this;
  }

  public OavpRhythm sensitivity(int sensitivity) {
    this.sensitivity = sensitivity;
    return this;
  }

  public void start() {
    out = minim.getLineOut();
    out.setTempo(tempo);
    out.pauseNotes();
    for (int i = 0; i < limit; ++i) {
      out.playNote(i * rhythm, 0.25, "C3");
    }
    out.resumeNotes();
    isPlaying = true;
    out.mute();
  }

  public void update() {
    beat.detect(out.mix);
  }

  public void toggleNotes() {
    if (isPlaying) {
      out.pauseNotes();
      isPlaying = false;
    } else {
      out.resumeNotes();
      isPlaying = true;
    }
  }

  public boolean onRhythm() {
    return beat.isOnset();
  }

  public void toggleMute() {
    if (out.isMuted()) {
      out.unmute();
    } else {
      out.mute();
    }
  }
}

public class OavpCounter {
  private float value = 0;
  private int count = 0;
  private int limit = 0;
  private Ani ani;
  private float duration = 1;
  private Easing easing = Ani.LINEAR;

  OavpCounter(){}

  public OavpCounter duration(float duration) {
    this.duration = duration;
    return this;
  }

  public OavpCounter easing(Easing easing) {
    this.easing = easing;
    return this;
  }

  public OavpCounter limit(int limit) {
    this.limit = limit;
    return this;
  }

  public void increment() {
    count++;
    ani = Ani.to(this, duration, "value", count, easing);
  }

  public void increment(float duration, Easing easing) {
    count++;
    ani = Ani.to(this, duration, "value", count, easing);
  }

  public void incrementIf(Boolean trigger) {
    if (trigger) {
      increment();
    }
  }

  public void incrementIf(Boolean trigger, float duration, Easing easing) {
    if (trigger) {
      increment(duration, easing);
    }
  }

  public float getValue() {
    return value;
  }

  public int getCount() {
    return count;
  }

  boolean hasFinished() {
    if (count % limit == 0) {
      increment();
      return true;
    }
    return false;
  }
}

public class OavpRotator {
  private float x = 0;
  private float y = 0;
  private float z = 0;
  private List storage;
  private float duration = 1;
  private Easing easing = Ani.LINEAR;
  private int index;
  private Ani aniX;
  private Ani aniY;
  private Ani aniZ;

  OavpRotator(){
    storage = new ArrayList();
  }

  public OavpRotator add(float x) {
    float[] values = new float[3];
    values[0] = x;
    storage.add(values);
    return this;
  }

  public OavpRotator add(float x, float y) {
    float[] values = new float[3];
    values[0] = x;
    values[1] = y;
    storage.add(values);
    return this;
  }

  public OavpRotator add(float x, float y, float z) {
    float[] values = new float[3];
    values[0] = x;
    values[1] = y;
    values[2] = z;
    storage.add(values);
    return this;
  }

  public OavpRotator addCombinations(float start, float end, int granularity) {
    float interpolation = (end - start) / max((granularity - 1), 1);
    for (int i = 0; i < max(granularity, 2); i++) {
      for (int j = 0; j < max(granularity, 2); j++) {
        float values[] = new float[]{i * interpolation, j * interpolation, 0};
        println(values);
        storage.add(values);
      }
    }
    return this;
  }

  public OavpRotator duration(float duration) {
    this.duration = duration;
    return this;
  }

  public OavpRotator easing(Easing easing) {
    this.easing = easing;
    return this;
  }

  public void rotate() {
    int currIndex = index % storage.size();
    index = index + 1 % storage.size();
    float[] values = (float[]) storage.get(currIndex);
    aniX = Ani.to(this, duration, "x", values[0], easing);
    aniY = Ani.to(this, duration, "y", values[1], easing);
    aniZ = Ani.to(this, duration, "z", values[2], easing);
  }

  public void randomize() {
    index = floor(random(0, storage.size())) % storage.size();
    float[] values = (float[]) storage.get(index);
    aniX = Ani.to(this, duration, "x", values[0], easing);
    aniY = Ani.to(this, duration, "y", values[1], easing);
    aniZ = Ani.to(this, duration, "z", values[2], easing);
  }

  public void rotateIf(boolean trigger) {
    if (trigger) {
      rotate();
    }
  }

  public void randomizeIf(boolean trigger) {
    if (trigger) {
      randomize();
    }
  }

  public float getX() {
    return x;
  }

  public float getY() {
    return y;
  }

  public float getZ() {
    return z;
  }
}

public class OavpColorRotator {
  private float value = 0;
  private List storage;
  private color colorA;
  private color colorB;
  private float duration = 1;
  private Easing easing = Ani.LINEAR;
  private int index;
  private Ani ani;

  OavpColorRotator(){
    storage = new ArrayList();
  }

  public OavpColorRotator add(color value) {
    storage.add(value);
    return this;
  }

  public OavpColorRotator duration(float duration) {
    this.duration = duration;
    return this;
  }

  public OavpColorRotator easing(Easing easing) {
    this.easing = easing;
    return this;
  }

  public void rotate() {
    colorA = (color) storage.get(index % storage.size());
    index = index + 1 % storage.size();
    colorB = (color) storage.get(index % storage.size());
    animate();
  }

  public void randomize() {
    colorA = (color) storage.get(index % storage.size());
    index = floor(random(0, storage.size())) % storage.size();
    colorB = (color) storage.get(index % storage.size());
    animate();
  }

  private void animate() {
    value = 0;
    ani = Ani.to(this, duration, "value", 1, easing);
  }

  public void rotateIf(boolean trigger) {
    if (trigger) {
      rotate();
    }
  }

  public void randomizeIf(boolean trigger) {
    if (trigger) {
      randomize();
    }
  }

  public color getColor() {
    return lerpColor(colorA, colorB, value);
  }
}

public class OavpOscillator {
  private float duration = 1;
  private Easing easing = Ani.LINEAR;
  private Ani ani;
  private float value = 0;

  public OavpOscillator duration(float duration) {
    this.duration = duration;
    return this;
  }

  public OavpOscillator easing(Easing easing) {
    this.easing = easing;
    return this;
  }

  OavpOscillator(){}

  public void start() {
    loop();
  }

  private void loop() {
    if (value == 0) {
      ani = Ani.to(this, duration, "value", 1, easing, "onEnd:loop");
    } else {
      ani = Ani.to(this, duration, "value", 0, easing, "onEnd:loop");
    }
  }

  public float getValue() {
    return value;
  }

  public float getValue(float start, float end) {
    return map(value, 0, 1, start, end);
  }
}

public class OavpTerrain {
  private float[] values;
  private int[] structures;
  private int size = 10000;
  private float granularity = 0.01;

  OavpTerrain() {
    values = new float[size];
    structures = new int[size];
    generate();
  }

  public OavpTerrain generate() {
    for (int i = 0; i < size; ++i) {
      values[i] = refinedNoise(i, granularity);
    }
    for (int i = 0; i < size; ++i) {
      structures[i] = floor(random(0, 20));
    }
    return this;
  }

  public OavpTerrain granularity(float granularity) {
    this.granularity = granularity;
    return this;
  }

  public OavpTerrain size(int size) {
    this.size = size;
    return this;
  }

  public float[] getValues(float position, int windowSize, int shift) {
    int index = floor(position);
    float[] out = new float[windowSize];
    if (index + windowSize + shift <= size) {
      for (int i = 0; i < windowSize; ++i) {
        out[i] = values[i + index + shift];
      }
      return out;
    } else {
      for (int i = 0; i < windowSize; i++) {
        out[(windowSize - 1) - i] = values[(size - 1) - i];
      }
      return out;
    }
  }

  public float[] getStructures(float position, int windowSize, int shift) {
    int index = floor(position);
    float[] out = new float[windowSize];
    if (index + windowSize + shift <= size) {
      for (int i = 0; i < windowSize; ++i) {
        out[i] = structures[i + index + shift];
      }
      return out;
    } else {
      for (int i = 0; i < windowSize; i++) {
        out[(windowSize - 1) - i] = structures[(size - 1) - i];
      }
      return out;
    }
  }

  public float[][] getWindow(float position, int windowSize, int shift) {
    int index = floor(position);
    float[] valuesWindow = new float[windowSize];
    float[] structuresWindow = new float[windowSize];
    float[][] out = new float[2][windowSize];
    if (index + windowSize + shift <= size) {
      for (int i = 0; i < windowSize; ++i) {
        valuesWindow[i] = values[i + index + shift];
        structuresWindow[i] = structures[i + index + shift];
      }
      out[0] = valuesWindow;
      out[1] = structuresWindow;
      return out;
    } else {
      for (int i = 0; i < windowSize; i++) {
        valuesWindow[(windowSize - 1) - i] = values[(size - 1) - i];
        structuresWindow[(windowSize - 1) - i] = structures[(size - 1) - i];
      }
      out[0] = valuesWindow;
      out[1] = structuresWindow;
      return out;
    }
  }
}

public class OavpEntityManager {
  private Minim minim;
  private HashMap<String, PShape> svgs;
  private HashMap<String, PImage> imgs;
  private HashMap<String, OavpPulser> pulsers;
  private HashMap<String, OavpInterval> intervals;
  private HashMap<String, OavpGridInterval> gridIntervals;
  private HashMap<String, List> emissionsStorage;
  private HashMap<String, OavpRhythm> rhythms;
  private HashMap<String, OavpCounter> counters;
  private HashMap<String, OavpRotator> rotators;
  private HashMap<String, OavpColorRotator> colorRotators;
  private HashMap<String, OavpOscillator> oscillators;
  private HashMap<String, OavpTerrain> terrains;
  private HashMap<String, OavpCamera> cameras;

  OavpEntityManager(Minim minim) {
    this.minim = minim;
    svgs = new HashMap<String, PShape>();
    imgs = new HashMap<String, PImage>();
    pulsers = new HashMap<String, OavpPulser>();
    intervals = new HashMap<String, OavpInterval>();
    gridIntervals = new HashMap<String, OavpGridInterval>();
    emissionsStorage = new HashMap<String, List>();
    rhythms = new HashMap<String, OavpRhythm>();
    counters = new HashMap<String, OavpCounter>();
    rotators = new HashMap<String, OavpRotator>();
    colorRotators = new HashMap<String, OavpColorRotator>();
    oscillators = new HashMap<String, OavpOscillator>();
    terrains = new HashMap<String, OavpTerrain>();
    cameras = new HashMap<String, OavpCamera>();
  }

  public float mouseX(float start, float end) {
    return map(mouseX, 0, width, start, end);
  }

  public float mouseY(float start, float end) {
    return map(mouseY, 0, height, start, end);
  }

  public void addSvg(String filename) {
    String[] fn = filename.split("\\.");
    svgs.put(fn[0], loadShape(filename));
  }

  public PShape getSvg(String name) {
    return svgs.get(name);
  }

  public void addImg(String filename) {
    String[] fn = filename.split("\\.");
    imgs.put(fn[0], loadImage(filename));
  }

  public PImage getImg(String name) {
    return imgs.get(name);
  }

  public OavpPulser addPulser(String name) {
    pulsers.put(name, new OavpPulser());
    return pulsers.get(name);
  }

  public OavpPulser getPulser(String name) {
    return pulsers.get(name);
  }

  public void addInterval(String name, int storageSize, int snapshotSize) {
    intervals.put(name, new OavpInterval(storageSize, snapshotSize));
  }

  public OavpInterval getInterval(String name) {
    return intervals.get(name);
  }

  public void addGridInterval(String name, int numRows, int numCols) {
    gridIntervals.put(name, new OavpGridInterval(numRows, numCols));
  }

  public OavpGridInterval getGridInterval(String name) {
    return gridIntervals.get(name);
  }

  public void addEmissions(String name) {
    emissionsStorage.put(name, new ArrayList());
  }

  public void updateEmissions() {
    for (HashMap.Entry<String, List> entry : emissionsStorage.entrySet())
    {
      Iterator<OavpEmission> i = entry.getValue().iterator();
      while(i.hasNext()) {
        OavpEmission item = i.next();
        item.update();
        if (item.isDead) {
          i.remove();
        }
      }
    }
  }

  public List getEmissions(String name) {
    return emissionsStorage.get(name);
  }

  public OavpRhythm addRhythm(String name) {
    rhythms.put(name, new OavpRhythm(minim));
    return rhythms.get(name);
  }

  public void updateRhythms() {
    for (HashMap.Entry<String, OavpRhythm> entry : rhythms.entrySet())
    {
      entry.getValue().update();
    }
  }

  public boolean onRhythm(String name) {
    return rhythms.get(name).onRhythm();
  }

  public OavpRhythm getRhythm(String name) {
    return rhythms.get(name);
  }

  public OavpCounter addCounter(String name) {
    counters.put(name, new OavpCounter());
    return counters.get(name);
  }

  public void incrementCounterIf(String name, Boolean trigger) {
    counters.get(name).incrementIf(trigger);
  }

  public void incrementCounter(String name) {
    counters.get(name).increment();
  }

  public boolean checkCounter(String name) {
    return counters.get(name).hasFinished();
  }

  public OavpCounter getCounter(String name) {
    return counters.get(name);
  }

  public OavpRotator addRotator(String name) {
    rotators.put(name, new OavpRotator());
    return rotators.get(name);
  }

  public OavpRotator getRotator(String name) {
    return rotators.get(name);
  }

  public void rotateRotator(String name) {
    rotators.get(name).rotate();
  }

  public void rotateRotatorIf(String name, boolean trigger) {
    rotators.get(name).rotateIf(trigger);
  }

  public void randomizeRotator(String name) {
    rotators.get(name).randomize();
  }

  public void randomizeRotatorIf(String name, boolean trigger) {
    rotators.get(name).randomizeIf(trigger);
  }

  public OavpColorRotator addColorRotator(String name) {
    colorRotators.put(name, new OavpColorRotator());
    return colorRotators.get(name);
  }

  public OavpColorRotator getColorRotator(String name) {
    return colorRotators.get(name);
  }

  public void rotateColorRotator(String name) {
    colorRotators.get(name).rotate();
  }

  public void rotateColorRotatorIf(String name, boolean trigger) {
    colorRotators.get(name).rotateIf(trigger);
  }

  public void randomizeColorRotator(String name) {
    colorRotators.get(name).randomize();
  }

  public void randomizeColorRotatorIf(String name, boolean trigger) {
    colorRotators.get(name).randomizeIf(trigger);
  }

  public OavpOscillator addOscillator(String name) {
    oscillators.put(name, new OavpOscillator());
    return oscillators.get(name);
  }

  public OavpOscillator getOscillator(String name) {
    return oscillators.get(name);
  }

  public OavpTerrain addTerrain(String name) {
    terrains.put(name, new OavpTerrain());
    return terrains.get(name);
  }

  public OavpTerrain getTerrain(String name) {
    return terrains.get(name);
  }

  public OavpCamera addCamera(String name) {
    cameras.put(name, new OavpCamera());
    return cameras.get(name);
  }

  public OavpCamera getCamera(String name) {
    return cameras.get(name);
  }

  public void useCamera(String name) {
    cameras.get(name).view();
  }

  public void update() {
    updateRhythms();
    updateEmissions();
  }
}