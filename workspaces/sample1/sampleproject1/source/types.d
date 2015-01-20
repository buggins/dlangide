/**
  This module contains some type definitions.  
 */
module types;

/**  2D point */
struct Point {
    /// x coordinate
    int x;
    /// y coordinate
    int y;
    this(int x0, int y0) {
        x = x0;
        y = y0;
    }
}

/**  2D rectangle */
struct Rect {
    /// x coordinate of top left corner
    int left;
    /// y coordinate of top left corner
    int top;
    /// x coordinate of bottom right corner
    int right;
    /// y coordinate of bottom right corner
    int bottom;
    /// returns average of left, right
    @property int middlex() { return (left + right) / 2; }
    /// returns average of top, bottom
    @property int middley() { return (top + bottom) / 2; }
    /// returns middle point
    @property Point middle() { return Point(middlex, middley); }
    /// add offset to horizontal and vertical coordinates
    void offset(int dx, int dy) {
        left += dx;
        right += dx;
        top += dy;
        bottom += dy;
    }
    /// expand rectangle dimensions
    void expand(int dx, int dy) {
        left -= dx;
        right += dx;
        top -= dy;
        bottom += dy;
    }
    /// shrink rectangle dimensions
    void shrink(int dx, int dy) {
        left += dx;
        right -= dx;
        top += dy;
        bottom -= dy;
    }
    /// for all fields, sets this.field to rc.field if rc.field > this.field
    void setMax(Rect rc) {
        if (left < rc.left)
            left = rc.left;
        if (right < rc.right)
            right = rc.right;
        if (top < rc.top)
            top = rc.top;
        if (bottom < rc.bottom)
            bottom = rc.bottom;
    }
    /// returns width of rectangle (right - left)
    @property int width() { return right - left; }
    /// returns height of rectangle (bottom - top)
    @property int height() { return bottom - top; }
    /// constructs rectangle using left, top, right, bottom coordinates
    this(int x0, int y0, int x1, int y1) {
        left = x0;
        top = y0;
        right = x1;
        bottom = y1;
    }
    /// returns true if rectangle is empty (right <= left || bottom <= top)
    @property bool empty() {
        return right <= left || bottom <= top;
    }
    /// translate rectangle coordinates by (x,y) - add deltax to x coordinates, and deltay to y coordinates
    void moveBy(int deltax, int deltay) {
        left += deltax;
        right += deltax;
        top += deltay;
        bottom += deltay;
    }
    /// moves this rect to fit rc bounds, retaining the same size
    void moveToFit(ref Rect rc) {
        if (right > rc.right)
            moveBy(rc.right - right, 0);
        if (bottom > rc.bottom)
            moveBy(0, rc.bottom - bottom);
        if (left < rc.left)
            moveBy(rc.left - left, 0);
        if (top < rc.top)
            moveBy(0, rc.top - top);

    }
    /// updates this rect to intersection with rc, returns true if result is non empty
    bool intersect(Rect rc) {
        if (left < rc.left)
            left = rc.left;
        if (top < rc.top)
            top = rc.top;
        if (right > rc.right)
            right = rc.right;
        if (bottom > rc.bottom)
            bottom = rc.bottom;
        return right > left && bottom > top;
    }
    /// returns true if this rect has nonempty intersection with rc
    bool intersects(Rect rc) {
        if (rc.left >= right || rc.top >= bottom || rc.right <= left || rc.bottom <= top)
            return false;
        return true;
    }
    /// returns true if point is inside of this rectangle
    bool isPointInside(Point pt) {
        return pt.x >= left && pt.x < right && pt.y >= top && pt.y < bottom;
    }
    /// returns true if point is inside of this rectangle
    bool isPointInside(int x, int y) {
        return x >= left && x < right && y >= top && y < bottom;
    }
    /// this rectangle is completely inside rc
    bool isInsideOf(Rect rc) {
        return left >= rc.left && right <= rc.right && top >= rc.top && bottom <= rc.bottom;
    }

    bool opEquals(Rect rc) {
        return left == rc.left && right == rc.right && top == rc.top && bottom == rc.bottom;
    }
}

