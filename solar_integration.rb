require 'sketchup.rb'
require 'solar_integration/progress.rb'
require 'solar_integration/grid.rb'
require 'solar_integration/spherical_hash_map.rb'
require 'solar_integration/shadow_caster.rb'
require 'solar_integration/sun_data.rb'
require 'solar_integration/data_collector.rb'
require 'solar_integration/polygon_collector.rb'
require 'solar_integration/configuration.rb'
require 'set'

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

UI.menu('Plugins').add_item('Visualize shadow pyramids') {
  model = Sketchup.active_model
  
  model.selection.select{|f|f.typename=='Face'}.each do |f|
    $solar_integration.visualize_shadow_pyramids(f)
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
    
    SunDataVisualizationSphere.new(face.parent.entities, center)
  end
  
  def visualize_hash_map(face)
    center = find_face_center(face)
    polygons = collect_model_polygons(Sketchup.active_model)
    shadow_caster = ShadowCaster.new(polygons, face, @configuration)
    shadow_caster.prepare_center(center)
    shadow_caster.prepare_position(center)
    HashMapVisualizationSphere.new(face.parent.entities, center, shadow_caster.hash_map, 10, 10, shadow_caster.sun_transformation)
  end
  
  def visualize_shadow_pyramids(face)
    center = find_face_center(face)
    polygons = collect_model_polygons(Sketchup.active_model)
    shadow_caster = ShadowCaster.new(polygons, face, @configuration)
    shadow_caster.prepare_center(center)
    shadow_caster.prepare_position(center)
    group = face.parent.entities.add_group
    pyramids = Set.new
    shadow_caster.hash_map.all_values.each{|a| a.each{|p|pyramids.add(p)}}
    progress = Progress.new(pyramids.length, 'Drawing pyramids...')
    Sketchup.active_model.start_operation('Drawing pyramids', true)
    pyramids.each do |p|
      p.visualize(group.entities, center)
      progress.work
    end
    Sketchup.active_model.commit_operation
  end
  
  def find_face_center(face)
    # center of gravity of vertices
    center = face.vertices
      .collect{|v|Geom::Vector3d.new v.position.to_a}.reduce(:+)
      .transform(1.0/face.vertices.length)
    return Geom::Point3d.new(center.to_a) + face.normal.normalize
  end
  
  def integrate(face)
    grid = Grid.new(face, @configuration.grid_length, @configuration.sub_divisions)
    
    polygons = collect_model_polygons(Sketchup.active_model)
    shadow_caster = ShadowCaster.new(polygons, face, @configuration)
    data_collectors = @configuration.active_data_collectors.collect { |c| c.new(grid) }
    
    render_t = 0
    prepare_center_t = 0
    prepare_position_t = 0
    progress = Progress.new(grid.number_of_subsquares, 'Integrating irradiances...')
    for square in grid.squares
      t1 = Time.new
      shadow_caster.prepare_center(square.center)
      t2 = Time.new
      for point in square.points
        data_collectors.each { |c| c.current_point=point }
        t3 = Time.new
        shadow_caster.prepare_position(point)
        t4 = Time.new
        render_point(grid.normal, shadow_caster, data_collectors)
        t5 = Time.new
        progress.work
        prepare_position_t += t4-t3
        render_t += t5-t4
      end
      prepare_center_t += t2-t1
    end
    data_collectors.each { |c| c.wrapup }
    puts "prepare center #{prepare_center_t.round(2)}, "\
      "prepare position #{prepare_position_t.round(2)}, "\
      "render time #{render_t.round(2)}"
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
