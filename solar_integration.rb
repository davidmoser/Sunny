require 'solar_integration/globals.rb'
require 'solar_integration/progress.rb'
require 'solar_integration/grid.rb'
require 'solar_integration/spherical_hash_map.rb'
require 'solar_integration/shadow_caster.rb'
require 'solar_integration/sun_data.rb'
require 'solar_integration/irradiance_statistics.rb'
require 'solar_integration/menu.rb'
require 'solar_integration/irradiance_rendering.rb'
require 'set'

SKETCHUP_CONSOLE.show

class SolarIntegration
  attr_reader :sun_data
  
  def initialize
    $configuration = Configuration.new
    $irradiance_statistics = IrradianceStatistics.new
    
    @sun_data = SunData.new
    Menu.new(self)
  end

  def visualize_sun_states(face)
    @sun_data.update
    center = find_face_center(face)
    SunDataVisualizationSphere.new(@sun_data, face.parent.entities, center)
  end
  
  def visualize_hash_map(face)
    center = find_face_center(face)
    shadow_caster = ShadowCaster.new(Grid.new(face))
    shadow_caster.prepare_center(center)
    shadow_caster.prepare_position(center)
    HashMapVisualizationSphere.new(face.parent.entities, center, shadow_caster.hash_map, 10, 10, SUN_TRANSFORMATION)
  end
  
  def visualize_shadow_pyramids(face)
    center = find_face_center(face)
    shadow_caster = ShadowCaster.new(Grid.new(face))
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
    return Geom::Point3d.new(center.to_a) + face.normal
  end
  
  def integrate(face)
    @sun_data.update
    rendering = IrradianceRendering.new(face, @sun_data)
    rendering.render()
  end
end

$solar_integration = SolarIntegration.new