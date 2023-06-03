use crate::prelude::*;

#[derive(Serialize, Deserialize, PartialEq, Debug, Clone)]
pub struct Properties {

    pub shape                       : Property,
    pub profile                     : Property,
    pub color_front                 : Property,
    pub color_side                  : Property,
    pub color_top                   : Property,
}

impl Properties {
    pub fn new() -> Self {
        Self {
            shape                   : Property::new(11),
            profile                 : Property::new(11),
            color_front             : Property::new(16),
            color_side              : Property::new(16),
            color_top               : Property::new(16),
        }
    }
}

#[derive(Serialize, Deserialize, PartialEq, Debug, Clone)]
pub struct Property {

    pub dimension                   : usize,
    pub pixels                      : Vec<u8>
}

impl Property {

    pub fn new(dim: usize) -> Self {

        Self {
            dimension               : dim,
            pixels                  : vec![0; dim * dim],
        }
    }

    pub fn get(&self, x: usize, y: usize) -> u8 {
        if x < self.dimension && y < self.dimension {
            self.pixels[x + y * self.dimension]
        } else {
            0
        }
    }

    pub fn set(&mut self, x: usize, y: usize, value: u8) {
        if x < self.dimension && y < self.dimension {
            self.pixels[x + y * self.dimension] = value;
        }
    }

    pub fn clear(&mut self, index: u8) {
        for i in 0..self.pixels.len() {
            self.pixels[i] = index;
        }
    }

    pub fn min_max(&self) -> Option<((f32, f32), (f32, f32), (f32, f32))> {

        let mut first : Option<(usize, usize)> = None;
        let mut last  : Option<(usize, usize)> = None;

        for y in 0..self.dimension {
            for x in 0..self.dimension {
                if self.get(x, y) == 0 {
                    continue;
                }
                if first.is_none() {
                    first = Some((x, y));
                } else {
                    last = Some((x, y));
                }
            }
        }

        if first.is_some() {
            if last.is_none() {
                last = first.clone();
            }

            let div = self.dimension;

            let min = (first.unwrap().0 as f32 / div as f32, first.unwrap().1 as f32 / div as f32);
            let max = (last.unwrap().0 as f32 / div as f32, last.unwrap().1 as f32 / div as f32);

            let middle = ((min.0 + max.0) / 2.0, (min.0 + max.0) / 2.0);

            return Some((
                min,
                middle,
                max
            ));
        }

        None
    }
}
