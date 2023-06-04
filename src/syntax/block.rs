use std::collections::BTreeMap;

use crate::prelude::*;

#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq)]
pub enum BlockType {
    MainFunction,
    Function,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Block {
    pub id                      : Uuid,

    pub name                    : String,
    pub block_type              : BlockType,

    pub arguments               : BTreeMap<String, Variable>,
    pub variables               : BTreeMap<String, Variable>,

    pub lines                   : Vec<Line>
}

impl Block {
    pub fn new(name: String, block_type: BlockType) -> Self {

        Self {
            id                  : Uuid::new_v4(),

            name,
            block_type,

            arguments           : BTreeMap::default(),
            variables           : BTreeMap::default(),

            lines               : vec![],
        }
    }
}