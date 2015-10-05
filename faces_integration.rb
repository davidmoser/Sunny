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
      integrate_grid(grid)
      component = get_component(face)
      if component
        integrate_instances(grid, component)
      end
    end
  end
  
  def integrate_grid(grid)
    rendering = IrradianceRendering.new(grid, @group, @sun_data)
    rendering.render()
  end
  
  # integrate all other instances (the selected instance is special
  # since ruby returns global coordinates for the group being edited)
  def integrate_instances(grid, component)
    for instance in component.instances
      transformation = get_transformation(instance)
      unless transformation.identity?
        component_grid = grid.transform(transformation)
        integrate_grid(component_grid)
      end
    end
  end
  
  def get_transformation(coords)
    transformation = Geom::Transformation.new
    while not coords.is_a? Sketchup::Model
      transformation = transformation * coords.transformation
      coords = coords.parent
    end
    return transformation
  end
  
  def get_component(entity)
    while not entity.is_a? Sketchup::Model
      return entity if entity.is_a? Sketchup::ComponentDefinition
      entity = entity.parent
    end
    return nil
  end
end