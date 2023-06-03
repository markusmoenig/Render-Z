pub use crate::prelude::*;

#[derive(Serialize, Deserialize, Clone, Debug)]
pub enum Value {
    Float(f32),
    Float2(Vec2f),
    Float3(Vec3f),
    Float4(Vec4f),
}

impl Value {

    /// Returns true if the variant is a float value
    pub fn is_float(&self) -> bool {
        match self {
            Float(_) | Float2(_) | Float3(_) | Float4(_) => {
                true
            },
            _ => {
                false
            }
        }
    }

    /// Returns true if the variants match
    pub fn variant_eq(&self, other: &Value) -> bool {
        std::mem::discriminant(self) == std::mem::discriminant(other)
    }
}