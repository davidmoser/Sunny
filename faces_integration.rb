require 'solar_integration/irradiance_rendering.rb'
require 'sketchup.rb'

class FacesIntegration
  
  def initialize(solar_integration)
    @configuration = solar_integration.configuration
    @sun_data = solar_integration.sun_data
  end
  
  def integrate(faces)
    @sun_data.update
    @configuration.save_to_model
    @group = Sketchup.active_model.entities.add_group
    @group.name = 'Solar Integration'
    for face in faces
      grid = Grid.new(face, @configuration)
      integrate_definition(face, grid)
    end
  end
  
  def integrate_grid(grid)
    rendering = IrradianceRendering.new(grid, @group, @sun_data)
    rendering.render()
  end
  
  def integrate_definition(face, grid)
    transformations = get_transformations(face.parent)
    for transformation in transformations
      component_grid = grid.transform(transformation)
      integrate_grid(component_grid)
    end
  end
  
  # gathers all transformations for our face, taking into account
  # nested component definitions / groups
  def get_transformations(definition)
    transformations = []
    if definition.is_a? Sketchup::Model
      transformations.push(Geom::Transformation.new)
    else
      definition.instances.each do |i|
        get_transformations(i.parent).each do |t|
          transformations.push(i.transformation*t)
        end
      end
    end
    return transformations
  end
  
end