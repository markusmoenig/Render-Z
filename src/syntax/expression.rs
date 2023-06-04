use crate::prelude::*;

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Expression {
    pub id                      : Uuid,

    pub functions               : Vec<Function>,
    pub operators               : Vec<char>,
}

impl Expression {
    pub fn new() -> Self {

        Self {
            id                  : Uuid::new_v4(),

            functions           : vec![],
            operators           : vec![],
        }
    }
}