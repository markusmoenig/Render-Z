use crate::prelude::*;

#[derive(Serialize, Deserialize, Clone, Copy, Debug)]
pub enum FunctionName {
    empty,
    float4,
    abs,
    sin,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Function {
    pub name                    : FunctionName,
    pub args                    : Vec<Function>
}

impl Function {
    pub fn new(name: FunctionName) -> Self {

        let args = match name {
            FunctionName::abs | FunctionName::sin => {
                vec![Function::new(FunctionName::empty)]
            },
            _ => {
                vec![]
            }
        };

        Self {
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
                Some(Function::new(FunctionName::abs))
            },
            "sin" => {
                Some(Function::new(FunctionName::sin))
            },
            _ => {
                None
            }
        }
    }
}