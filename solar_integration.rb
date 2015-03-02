require 'sketchup.rb'
require 'solar_integration/progress.rb'
require 'solar_integration/grid.rb'
require 'solar_integration/spherical_hash_map.rb'
require 'solar_integration/shadow_caster.rb'
require 'solar_integration/sun_data.rb'
require 'solar_integration/data_collector.rb'
require 'solar_integration/polygon_collector.rb'
require 'solar_integration/configuration.rb'

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

UI.menu('Plugins').add_item('Print polygons') {
  model = Sketchup.active_model
  
  for p in collect_model_polygons(model)
    puts p
  end
}

UI.menu('Plugins').add_item('Configuration ...') {
  $solar_integration.update_configuration
}

class SolarIntegration
  def initialize
    @sun_data = SunData.new
    @configuration = Configuration.new
  end
  
  def update_configuration
    @configuration.update
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
    center = Geom::Point3d.new(center.to_a) + face.normal.normalize
    
    polygons = collect_model_polygons(Sketchup.active_model)
    shadow_caster = ShadowCaster.new(polygons, face, @configuration)
    shadow_caster.prepare_position(center)
    HashMapVisualizationSphere.new(face.parent.entities, center, shadow_caster.hash_map, 10, 10)
  end
  
  def integrate(face)
    grid = Grid.new(face, @configuration.grid_length, @configuration.sub_divisions)
    
    polygons = collect_model_polygons(Sketchup.active_model)
    shadow_caster = ShadowCaster.new(polygons, face, @configuration)
    data_collectors = @configuration.active_data_collectors.collect { |c| c.new(grid) }
    
    render_time = 0
    progress = Progress.new(grid.number_of_subsquares, 'Integrating irradiances...')
    for square in grid.squares
      shadow_caster.prepare_center(square.center)
      for point in square.points
        data_collectors.each { |c| c.current_point=point }
        shadow_caster.prepare_position(point)
        t1 = Time.new
        render_point(grid.normal, shadow_caster, data_collectors)
        t2 = Time.new
        render_time += t2-t1
        progress.work 
      end
    end
    puts "Render time #{render_time.round(2)}"
    shadow_caster.print_times
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
