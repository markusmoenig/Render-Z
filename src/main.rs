use theframework::*;

pub mod editor;
pub mod ui;
pub mod property;
pub mod tool;
pub mod buffer;
pub mod syntax;

use rust_embed::RustEmbed;
#[derive(RustEmbed)]
#[folder = "embedded/"]
#[exclude = ".txt"]
#[exclude = ".DS_Store"]
pub struct Embedded;

pub mod prelude {

    pub use theframework::TheContext;

    pub use crate::Embedded;
    pub use rustc_hash::FxHashMap;
    pub use uuid::Uuid;
    pub use serde::{Deserialize, Serialize};

    pub use crate::buffer::ColorBuffer;
    pub use maths_rs::prelude::*;

    pub use crate::ui::prelude::*;

    pub use crate::editor::{Editor};
    pub use crate::property::*;
    pub use crate::tool::Tool;
    pub use crate::ui::UI;

    pub use crate::syntax::function::{Function, FunctionName, FunctionName::*};
    pub use crate::syntax::value::{Value, Value::*};
    pub use crate::syntax::block::*;
    pub use crate::syntax::line::*;
    pub use crate::syntax::variable::*;
}

use prelude::*;

fn main() {

    let editor = Editor::new();
    let mut app = TheApp::new();

    _ = app.run(Box::new(editor));
}
