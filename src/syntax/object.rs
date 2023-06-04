use crate::prelude::*;

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Object {
    pub id                      : Uuid,

    pub nodes                   : Vec<Node>,
}

impl Object {
    pub fn new() -> Self {

        Self {
            id                  : Uuid::new_v4(),

            nodes               : vec![]
        }
    }

    pub fn add_shader(&mut self, ) {

    }

    /// Get a reference to the given object id
    pub fn get_node(&self, id: Uuid) -> Option<&Node> {
        for n in &self.nodes {
            if n.id == id {
                return Some(n)
            }
        }
        None
    }

    /// Get a mut reference to the given object id
    pub fn get_node_mut(&mut self, id: Uuid) -> Option<&mut Node> {
        for n in &mut self.nodes {
            if n.id == id {
                return Some(n)
            }
        }
        None
    }
}