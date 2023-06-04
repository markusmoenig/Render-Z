use crate::prelude::*;

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Line {
    pub id                      : Uuid,

    pub variable                : Variable,
    pub expressions             : Vec<Expression>
}

impl Line {
    pub fn new() -> Self {

        Self {
            id                  : Uuid::new_v4(),

            variable            : Variable::empty(),
            expressions         : vec![],
        }
    }
}