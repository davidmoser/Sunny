require 'sketchup.rb'
require 'solar_integration/progress.rb'
require 'solar_integration/grid.rb'
require 'solar_integration/spherical_hash_map.rb'
require 'solar_integration/shadow_caster.rb'
require 'solar_integration/sun_data.rb'
require 'solar_integration/data_collector.rb'
require 'solar_integration/model_exploder.rb'

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

UI.menu('Plugins').add_item('Visualize sun states') {
  model = Sketchup.active_model
  
  model.selection.select{|f|f.typename=='Face'}.each do |f|
    $solar_integration.visualize_sun_states(f)
  end
}

class SolarIntegration
  def initialize
    @grid_length = 10 ##TODO: is that always cm?
    @sun_data = SunData.new
    @data_collector_classes = [PolarAngleIrradianceHistogram, TotalIrradianceSquares]
  end

  def visualize_sun_states(face)
    # center of gravity of vertices
    center = face.vertices
      .collect{|v|Geom::Vector3d.new v.position.to_a}.reduce(:+)
      .transform(1.0/face.vertices.length)
    center = Geom::Point3d.new center.to_a
    
    SunDataVisualizationSphere.new(face.parent.entities, center, @sun_data)
  end
  
  def visualize_hash_map(face)
    # center of gravity of vertices
    center = face.vertices
      .collect{|v|Geom::Vector3d.new v.position.to_a}.reduce(:+)
      .transform(1.0/face.vertices.length)
    center = Geom::Point3d.new center.to_a
    
    polygons = explode_model(Sketchup.active_model)
    shadow_caster = ShadowCaster.new(polygons, face)
    shadow_caster.prepare_position(center)
    HashMapVisualizationSphere.new(face.parent.entities, center, shadow_caster.hash_map, 10, 10)
  end
  
  def integrate(face)
    grid = Grid.new(face, @grid_length)
    
    polygons = explode_model(Sketchup.active_model)
    shadow_caster = ShadowCaster.new(polygons, face)
    data_collectors = @data_collector_classes.collect { |c| c.new(grid) }
    
    progress = Progress.new(grid.points.length, 'Integrating irradiances...')
    for point in grid.points
      shadow_caster.prepare_position(point)
      data_collectors.each { |c| c.current_point=point }
      render_point(grid.normal, shadow_caster, data_collectors)
      progress.work
    end
    data_collectors.each { |c| c.wrapup }
  end
  
  def render_point(normal, shadow_caster, data_collectors)
    for state in @sun_data.states
      irradiance = nil
      if state.vector%normal > 0 and !shadow_caster.has_shadow(state.vector)
        irradiance = (normal % state.vector) * state.tsi
      end
      data_collectors.each {|c| c.put(state, irradiance)}
    end
  end
  
end

$solar_integration = SolarIntegration.new
