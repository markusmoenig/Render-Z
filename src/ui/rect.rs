#[derive(PartialEq, Eq, Hash, Copy, Clone, Debug)]
pub struct Rect {
    pub x                   : usize,
    pub y                   : usize,
    pub width               : usize,
    pub height              : usize,
}

impl Rect {

    pub fn new(x: usize, y: usize, width: usize, height: usize) -> Self {
        Self {
            x               : x,
            y               : y,
            width           : width,
            height          : height
        }
    }

    pub fn new_with_size(width: usize, height: usize) -> Self {
        Self {
            x               : 0,
            y               : 0,
            width           : width,
            height          : height
        }
    }

    pub fn empty() -> Self {
        Self {
            x               : 0,
            y               : 0,
            width           : 0,
            height          : 0
        }
    }

    pub fn from(tuple: (usize, usize, usize, usize)) -> Self {
        Self {
            x               : tuple.0,
            y               : tuple.1,
            width           : tuple.2,
            height          : tuple.3
        }
    }

    pub fn is_inside(&self, p: (usize, usize)) -> bool {
        p.0 >= self.x && p.1 >= self.y && p.0 < self.x + self.width && p.1 < self.y + self.height
    }

    pub fn to_usize(&self) -> (usize, usize, usize, usize) {
        (self.x as usize, self.y as usize, self.width as usize, self.height as usize)
    }
}