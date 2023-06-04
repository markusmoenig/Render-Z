use crate::prelude::*;

#[derive(Serialize, Deserialize, Clone, Copy, Debug)]
pub enum FunctionName {
    Empty,
    F4,
    Abs,
    Sin,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Function {
    pub id                      : Uuid,

    pub name                    : FunctionName,
    pub args                    : Vec<Function>
}

impl Function {
    pub fn new(name: FunctionName) -> Self {

        let args = match name {
            FunctionName::Abs | FunctionName::Sin => {
                vec![Function::new(FunctionName::Empty)]
            },
            _ => {
                vec![]
            }
        };

        Self {
            id                  : Uuid::new_v4(),

            name,
            args,
        }
    }

    /// Resolve the function into a value
    pub fn resolve() -> Value {
        Value::Float(0.0)
    }

    /// Create a function from a String
    pub fn create(name: &str) -> Option<Function> {
        match name {
            "abs" => {
                Some(Function::new(FunctionName::Abs))
            },
            "sin" => {
                Some(Function::new(FunctionName::Sin))
            },
            _ => {
                None
            }
        }
    }
}