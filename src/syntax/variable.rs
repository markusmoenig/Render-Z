use crate::prelude::*;

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Variable {
    pub id                      : Uuid,

    pub value                   : Option<Value>,
    pub reference               : Option<Uuid>,
}

impl Variable {

    pub fn empty() -> Self {

        Self {
            id                  : Uuid::new_v4(),

            value               : None,
            reference           : None,
        }
    }

    pub fn new(value: Value) -> Self {

        Self {
            id                  : Uuid::new_v4(),

            value               : Some(value),
            reference           : None,
        }
    }

    pub fn new_reference(uuid: Uuid) -> Self {

        Self {
            id                  : Uuid::new_v4(),

            value               : None,
            reference           : Some(uuid),
        }
    }
}