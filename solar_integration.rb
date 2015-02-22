require 'sketchup.rb'
require 'progressbar.rb'
require 'solar_integration/grid.rb'
require 'solar_integration/spherical_hash_map.rb'
require 'solar_integration/shadow_caster.rb'
require 'solar_integration/sun_data.rb'

SKETCHUP_CONSOLE.show

UI.menu('Plugins').add_item('Integrate selection') {
  model = Sketchup.active_model
  
  model.selection.select{|f|f.typename=='Face'}.each do |f|
    $solar_integration.integrate(f)
  end
}

UI.menu('Plugins').add_item('Visualize spherical hash map') {
  model = Sketchup.active_model
  
  model.selection.select{|f|f.typename=='Face'}.each do |f|
    $solar_integration.visualize_hash_map(f)
  end
}

class SolarIntegration
  def initialize
    @grid_length = 10 ##TODO: is that always cm?
    @sun_data = SunData.new
  end

  def visualize_hash_map(face)
    # center of gravity of vertices
    center = face.vertices
      .collect{|v|Geom::Vector3d.new v.position.to_a}.reduce(:+)
      .transform(1.0/face.vertices.length)
    center = Geom::Point3d.new center.to_a
    
    shadow_caster = ShadowCaster.new(face)
    shadow_caster.prepare_position(center)
    HashMapVisualizationSphere.new(center, shadow_caster.hash_map, 10, 10)
  end
  
  def integrate(face)
    grid = Grid.new(face, @grid_length)
    
    progress_bar = ProgressBar.new(grid.squares.length, 'Integrating irradiances...')
    
    shadow_caster = ShadowCaster.new(face)
    for square in grid.squares
      shadow_caster.prepare_position(square.center)
      square.irradiance = integrate_square(grid.normal, shadow_caster)
      progress_bar.update(grid.squares.find_index(square))
    end
    minmax = grid.squares.collect{|s| s.irradiance}.minmax
    color_bar = ColorBar.new(*minmax)
    grid.squares.each {|s| s.color_bar=color_bar }
  end
  
  def integrate_square(normal, shadow_caster)
    # integrate over all solar position and tsis for point
    irradiance = 0
    for state in @sun_data.states
      if state.vector%normal > 0 and !shadow_caster.has_shadow(state.vector)
        irradiance += (normal % state.vector) * state.tsi
      end
    end
    return irradiance
  end
  
end

$solar_integration = SolarIntegration.new
