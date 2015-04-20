require 'sketchup.rb'
require 'solar_integration/globals.rb'
require 'solar_integration/progress.rb'
require 'solar_integration/grid.rb'
require 'solar_integration/spherical_hash_map.rb'
require 'solar_integration/shadow_caster.rb'
require 'solar_integration/sun_data.rb'
require 'solar_integration/data_collector.rb'
require 'solar_integration/polygon_collector.rb'
require 'solar_integration/configuration.rb'
require 'solar_integration/sky_sections.rb'
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
  include PolygonCollector
  
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
    sky_sections = SkySections.new([], 10, @configuration)
    shadow_caster = ShadowCaster.new(polygons, face, sky_sections, @configuration)
    shadow_caster.prepare_center(center)
    shadow_caster.prepare_position(center)
    HashMapVisualizationSphere.new(face.parent.entities, center, shadow_caster.hash_map, 10, 10, SUN_TRANSFORMATION)
  end
  
  def visualize_shadow_pyramids(face)
    center = find_face_center(face)
    polygons = collect_model_polygons(Sketchup.active_model)
    sky_sections = SkySections.new([], 10, @configuration)
    shadow_caster = ShadowCaster.new(polygons, face, sky_sections, @configuration)
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
    
    data_collectors = @configuration.active_data_collectors.collect { |c| c.new(grid) }
    irradiances = calculate_irradiances(face.normal)
    sky_sections = SkySections.new(irradiances.keys, 10, @configuration)
    sky_sections.sections.each{|s| render_section(s, irradiances, data_collectors)}
    
    shadow_caster = ShadowCaster.new(polygons, face, sky_sections, @configuration)
    
    render_t = 0
    prepare_center_t = 0
    prepare_position_t = 0
    progress = Progress.new(grid.number_of_subsquares, 'Integrating irradiances...')
    for square in grid.squares
      t1 = Time.new
      shadow_caster.prepare_center(square.center)
      t2 = Time.new
      for point in square.points
        t3 = Time.new
        prepare_point(point, shadow_caster, data_collectors)
        t4 = Time.new
        render_shadows(irradiances, shadow_caster, data_collectors, sky_sections)
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
  
  def calculate_irradiances(normal)
    irradiances = Hash.new
    for state in @sun_data.states
      vector = state.local_vector
      if vector%Z_AXIS > 0 and vector%normal > 0
        irradiances[state] = (normal % vector) * state.tsi
      end
    end
    return irradiances
  end
  
  def render_section(sky_section, irradiances, data_collectors)
    for state in sky_section.sun_states
      data_collectors.each {|c| c.prepare_section(state, irradiances[state], sky_section)}
    end
  end
  
  def prepare_point(point, shadow_caster, data_collectors)
    data_collectors.each { |c| c.current_point=point }
    shadow_caster.prepare_position(point)
  end
  
  def render_shadows(irradiances, shadow_caster, data_collectors, sky_sections)
    with_shadow = 0
    without_shadow = 0
    for sky_section in sky_sections.sections
      if shadow_caster.is_shadow_section? sky_section
        with_shadow += 1
        for state in sky_section.sun_states
          irradiance = nil
          if !shadow_caster.has_shadow? state.vector
            irradiance = irradiances[state]
          end
          data_collectors.each {|c| c.put(state, irradiance)}
        end
      else
        without_shadow += 1
        data_collectors.each {|c| c.put_section(sky_section)}
      end
    end
    puts "#{with_shadow}/#{without_shadow}"
  end
  
end

$solar_integration = SolarIntegration.new
