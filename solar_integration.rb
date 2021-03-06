require 'sketchup.rb'
require 'solar_integration/globals.rb'
require 'solar_integration/progress.rb'
require 'solar_integration/grid.rb'
require 'solar_integration/spherical_hash_map.rb'
require 'solar_integration/shadow_caster.rb'
require 'solar_integration/menu.rb'
require 'solar_integration/irradiance_rendering.rb'
require 'solar_integration/faces_integration.rb'
require 'solar_integration/solar_integration_app_observer.rb'
require 'set'

SKETCHUP_CONSOLE.show

class SolarIntegration
  attr_accessor :configuration, :statistics, :sun_data

  def initialize
    @configuration = Configuration.new
    @statistics = IrradianceStatistics.new
    @sun_data = SunData.new

    Sketchup.add_observer(SolarIntegrationAppObserver.new(self))

    Menu.new(self)
  end

  def visualize_sun_states(face)
    @sun_data.update
    center = find_face_center(face)
    SunDataVisualizationSphere.new(@sun_data, face.parent.entities, center)
  end

  def visualize_hash_map(face)
    center = find_face_center(face)
    @sun_data.update
    shadow_caster = ShadowCaster.new(Grid.new(face, @configuration), @sun_data.sun_transformation)
    shadow_caster.prepare_center(center)
    shadow_caster.prepare_position(center)
    HashMapVisualizationSphere.new(face.parent.entities, center, shadow_caster.hash_map, @sun_data.sun_transformation)
  end

  def visualize_shadow_pyramids(face)
    center = find_face_center(face)
    @sun_data.update
    shadow_caster = ShadowCaster.new(Grid.new(face, @configuration), @sun_data.sun_transformation)
    shadow_caster.prepare_center(center)
    shadow_caster.prepare_position(center)
    group = Sketchup.active_model.entities.add_group
    group.name = 'Shadow Pyramids'
    pyramids = Set.new
    shadow_caster.hash_map.all_values.each { |a| a.each { |p| pyramids.add(p) } }
    progress = Progress.new(pyramids.length, 'Drawing pyramids')
    pyramids.each do |p|
      p.visualize(group.entities, center)
      progress.work
    end
    progress.finish
  end

  def find_face_center(face)
    # center of gravity of vertices
    center = face.vertices
                 .collect { |v| Geom::Vector3d.new v.position.to_a }.reduce(:+)
                 .transform(1.0/face.vertices.length)
    return Geom::Point3d.new(center.to_a) + face.normal
  end

  def integrate
    faces = Sketchup.active_model.selection.select { |f| f.typename=='Face' }
    integration = FacesIntegration.new(self)
    integration.integrate(faces)
  end

end

$solar_integration = SolarIntegration.new