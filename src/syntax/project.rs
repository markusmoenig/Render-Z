use crate::prelude::*;
use rayon::{slice::ParallelSliceMut, iter::{IndexedParallelIterator, ParallelIterator}};

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Project {
    pub id                      : Uuid,

    pub objects                 : Vec<Object>,
}

impl Project {
    pub fn new() -> Self {

        Self {
            id                  : Uuid::new_v4(),

            objects             : vec![]
        }
    }

    /// Generates a project with a basic / empth shader node
    pub fn gen_default_shader_project(&mut self) {
        let mut object = Object::new();
        let mut node = Node::new("Shader".to_string(), NodeType::Shader);
        let mut color_block = Block::new("color".to_string(), BlockType::MainFunction);

        let mut color_out_var = Variable::new(Value::Float4(vec4f(1.0, 0.0, 0.0, 1.0)));

        color_block.variables.insert("color".into(), color_out_var);
        node.blocks = vec![color_block];

        object.nodes = vec![node];
        self.objects = vec![object];
    }

    pub fn render_object(&mut self, buffer: &mut ColorBuffer, object_id: Uuid, node_id: Option<Uuid>) {

        let width = buffer.width;
        let height = buffer.height as f32;

        let start = self.get_time();

        if let Some(object) = self.get_object(object_id) {
            let screen = vec2f(buffer.width as f32, buffer.height as f32);

            buffer.pixels
                .par_rchunks_exact_mut(width * 4)
                .enumerate()
                .for_each(|(j, line)| {
                    for (i, pixel) in line.chunks_exact_mut(4).enumerate() {
                        let i = j * width + i;

                        let x = (i % width) as f32;
                        let y = height - (i / width) as f32;

                        let uv = vec2f(x / width as f32, 1.0 - (y / height));

                        let mut color = [uv.x, uv.y, 0.0, 1.0];

                        if let Some(node_id) = node_id {
                            if let Some(node) = object.get_node(node_id) {

                                let c = node.resolve_shader(uv, screen);
                                color[0] = c.x;
                                color[1] = c.y;
                                color[2] = c.z;
                                color[3] = c.w;
                            }
                        }

                        pixel.copy_from_slice(&color);
                    }
            });
        }

        let stop = self.get_time();
        println!("tick time {:?}", stop - start);
    }

    /// Get a reference to the given object id
    pub fn get_object(&self, id: Uuid) -> Option<&Object> {
        for o in &self.objects {
            if o.id == id {
                return Some(o)
            }
        }
        None
    }

    /// Get a mut reference to the given object id
    pub fn get_object_mut(&mut self, id: Uuid) -> Option<&mut Object> {
        for o in &mut self.objects {
            if o.id == id {
                return Some(o)
            }
        }
        None
    }

    /// Gets the current time in milliseconds
    fn get_time(&self) -> u128 {
        use std::time::{SystemTime, UNIX_EPOCH};
        let stop = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("Time went backwards");
            stop.as_millis()
    }
}