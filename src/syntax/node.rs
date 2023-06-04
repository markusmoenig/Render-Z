use crate::prelude::*;

#[derive(Serialize, Deserialize, Clone, Copy, Debug)]
pub enum NodeType {
    Shader,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Node {
    pub id                      : Uuid,

    pub name                    : String,
    pub node_type               : NodeType,
    pub blocks                  : Vec<Block>
}

impl Node {
    pub fn new(name: String, node_type: NodeType) -> Self {

        Self {
            id                  : Uuid::new_v4(),

            name,
            node_type,
            blocks              : vec![],
        }
    }

    /// Resolves a shader
    pub fn resolve_shader(&self, uv: Vec2f, screen: Vec2f) -> Vec4f {
        for b in &self.blocks {
            if b.block_type == BlockType::MainFunction {
                if let Some(color) = b.variables.get(&"color".to_string()) {
                    if let Some(value) = &color.value {
                        match value {
                            Float4(v) => {
                                return *v;
                            },
                            _ => {}
                        }
                    }
                }
            }
        }
        Vec4f::zero()
    }
}