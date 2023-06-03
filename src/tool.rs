use crate::prelude::*;

#[derive(Clone)]
pub struct Tool {
    pub script                  : String,
    pub widget_values           : Vec<WidgetValue>
}

impl Tool {
    pub fn new(script: String) -> Self {

        Self {
            script,
            widget_values       : vec![],
        }
    }

    pub fn init(&mut self) {
    }

    /// Returns the name of the tool
    pub fn name(&self) -> String  {
        "Render-Z".to_string()
    }
}