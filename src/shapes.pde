public class OavpShape {

  OavpShape() {}

  void flatbox(float x, float y, float z, float width, float height, float depth) {
    float[] a = { x, y, z };
    float[] b = { x + width, y, z };
    float[] c = { x + width, y, z + depth };
    float[] d = { x, y, z + depth };
    float[] e = { x, y + height, z };
    float[] f = { x + width, y + height, z };
    float[] g = { x + width, y + height, z + depth };
    float[] h = { x, y + height, z + depth };

    // Face 1
    beginShape();
    vertex(a[0], a[1], a[2]);
    vertex(b[0], b[1], b[2]);
    vertex(c[0], c[1], c[2]);
    vertex(d[0], d[1], d[2]);
    endShape(CLOSE);

    // Face 2
    beginShape();
    vertex(e[0], e[1], e[2]);
    vertex(f[0], f[1], f[2]);
    vertex(g[0], g[1], g[2]);
    vertex(h[0], h[1], h[2]);
    endShape(CLOSE);

    pushStyle();
    fill(palette.flat.white);

    // Face 3
    beginShape();
    vertex(h[0], h[1], h[2]);
    vertex(g[0], g[1], g[2]);
    vertex(c[0], c[1], c[2]);
    vertex(d[0], d[1], d[2]);
    endShape(CLOSE);

    // Face 4
    beginShape();
    vertex(h[0], h[1], h[2]);
    vertex(e[0], e[1], e[2]);
    vertex(a[0], a[1], a[2]);
    vertex(d[0], d[1], d[2]);
    endShape(CLOSE);

    fill(palette.flat.black);

    // Face 5
    beginShape();
    vertex(e[0], e[1], e[2]);
    vertex(f[0], f[1], f[2]);
    vertex(b[0], b[1], b[2]);
    vertex(a[0], a[1], a[2]);
    endShape(CLOSE);

    // Face 6
    beginShape();
    vertex(g[0], g[1], g[2]);
    vertex(f[0], f[1], f[2]);
    vertex(b[0], b[1], b[2]);
    vertex(c[0], c[1], c[2]);
    endShape(CLOSE);
    popStyle();
  }

  void chevron(float x, float y, float w, float h) {
    pushStyle();
    noFill();
    beginShape();

    // Centered
    vertex(x - w/2, y + h/2);
    vertex(x, y - h/2);
    vertex(x + w/2, y + h/2);

    // Cornered
    // vertex(x, y + h);
    // vertex(x + w/2, y);
    // vertex(x + w, y + h);

    endShape();
    popStyle();
  }

  void hill(float x, float y, float w, float h, float displacement, float scale, int numPoints, float granularity, float variance) {

    float[] points = new float[numPoints];
    int[] structures = new int[numPoints];
    float distance = w / numPoints;

    for (int i = 0; i < numPoints; ++i) {
      points[i] = refinedNoise(i, variance, granularity) * scale + displacement;
      structures[i] = quantizedNoise(i, variance, granularity, 5);
    }

    for (int i = 1; i < numPoints - 1; i++) {
      if (
        (structures[i] == 1 && structures[i - 1] != 1)
        ||
        (structures[i] == 2 && structures[i - 1] != 2)
      ) {
        float radius;
        if (structures[i + 1] == 1) {
          radius = 10;
        } else if (structures[i + 1] == 2) {
          radius = 30;
        } else {
          radius = 20;
        }
        line(w - (i * distance), points[i], w - (i * distance), points[i] - 30);
        ellipse(w - (i * distance), points[i] - 30, radius, radius);
      }
    }

    beginShape();
    vertex(x, points[points.length - 1]);
    vertex(x, h);
    vertex(w, h);
    for (int i = 0; i < points.length; i++) {
      vertex(w - (i * distance), points[i]);
    }
    vertex(x, points[points.length - 1]);
    endShape();
  }

  void trapezoid(float x, float y, float w, float h, float displacementA, float displacementB) {
    pushStyle();
    fill(palette.flat.black);
    beginShape();
    vertex(x, y + displacementA);
    vertex(x, y + h);
    vertex(x + w, y + h);
    vertex(x + w, y + displacementB);
    vertex(x, y + displacementA);
    endShape(CLOSE);
    popStyle();
  }

  void cylinder(float x, float y, float h, float radius, int numCircles) {
    float distance = h / numCircles;
    for (int i = 0; i < numCircles; i++) {
      float mult = cos(radians(map(i, 0, numCircles, 0, 360)));
      ellipse(x, y + (i * distance), (radius / 2) + (radius / 2) * mult, distance * 1.25);
    }
  }
}