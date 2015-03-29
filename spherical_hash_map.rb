require 'solar_integration/progress.rb'
require 'solar_integration/angle_conversion.rb'

class AbstractHashMap
  def initialize(resolution)
    @map = Hash.new{|m,k| m[k]=[]} # empty list is the default
  end
  
  def add_value(polygon, value)
    raise 'need to implement' 
  end
  
  def get_values(point)
    return @map[get_hash(point)]
  end
  
  def all_values
    return @map.values
  end
  
  def get_hash(point)
    raise 'need to implement' 
  end
end

# Simpler hashes for comparison
class NoHashMap < AbstractHashMap
  def add_value(polygon, value)
    @map[0].push value
  end
  
  def get_hash(point)
    return 0
  end
end

class AzimuthHashMap < AbstractHashMap
  def initialize(resolution)
    super(resolution)
    @azimuth_class = Class.new(AzimuthHashInterval)
    @azimuth_class.angular_resolution = resolution
  end
  
  def add_value(polygon, value)
    azimuth_hashes = @azimuth_class.new(polygon)
    azimuth_hashes.hash_array.each{|h| @map[h].push value}
  end
  
  def get_hash(point)
    return @azimuth_class.calculate_hash(point)
  end
end

class PolarHashMap < AbstractHashMap
  def initialize(resolution)
    super(resolution) # empty list is the default
    @polar_class = Class.new(PolarHashInterval)
    @polar_class.angular_resolution = resolution
  end
  
  def add_value(polygon, value)
    polar_hashes = @polar_class.new(polygon)
    polar_hashes.hash_array.each{|h| @map[h].push value}
  end
  
  def get_hash(point)
    return @polar_class.calculate_hash(point)
  end
end

# categorize and retrieve values according to the spherical angles that the
# polygon covers (as a chain of line segments)
# each value may up in multiple 'angle-bins' covered by its chain
class SphericalHashMap < AbstractHashMap
  def initialize(resolution)
    super(resolution)
    @azimuth_class = Class.new(AzimuthHashInterval)
    @azimuth_class.angular_resolution = resolution
    @polar_class = Class.new(PolarHashInterval)
    @polar_class.angular_resolution = resolution
  end
  
  def add_value(polygon, value)
    azimuth_hashes = @azimuth_class.new(polygon)
    polar_hashes = @polar_class.new(polygon)
    # not using array.product(array) because it's slow
    keys = []
    for i in azimuth_hashes.hash_array
      for j in polar_hashes.hash_array
        keys.push [i,j]
        @map[[i,j]].push value
      end
    end
    return keys
  end
  
  def get_hash(point)
    azimuth_hash = @azimuth_class.calculate_hash(point)
    polar_hash = @polar_class.calculate_hash(point)
    return [azimuth_hash, polar_hash]
  end
  
  def delete_value(keys, value)
    keys.each{|k| @map[k].delete(value)}
  end
end

# determines the range of polar angle that a polygon covers
# the polygon needs to be planar and convex for the
# north/south pole check to work
class PolarMinMax
  attr_reader :pl_min, :pl_max
  
  @@vertical = Geom::Vector3d.new(0,0,1)
  
  def initialize(polygon)
    @normals = []
    
    @pl_min, @pl_max = polygon.collect.with_index{
      |p,i| calculate_segment_angles(p, polygon[(i+1)%polygon.length])
    }.flatten.minmax
    
    # make sure the normals point inwards
    if @normals[0] % polygon[2] < 0
      @normals.collect! {|n| n.reverse}
    end
    # polygon surrounds north pole
    if @normals.all?{|n| n[2]>0}
      @pl_min = 0
    end
    # polygon surrounds south pole
    if @normals.all?{|n| n[2]<0}
      @pl_max = Math::PI
    end
  end
  
  def calculate_segment_angles(p1, p2)
    angles = []
    angles.push self.class.calculate_polar_angle(p1)
    angles.push self.class.calculate_polar_angle(p2)
    
    k = p1*p2 # k-plane spanned by p1, p2
    m = k * @@vertical # the potential max/min polar angles of p1-p2 lie in the
              # intersection of the k- and m-plane
    
    @normals.push k # need that for north-/south-pole check
    
    # check if intersection of line p1-p2 is on segment p1-p2
    l = (m % p2) / (m % (p2 - p1)) # intersection coefficient
    if l>0 and l<1
      s = Geom::Vector3d.linear_combination(l, p1, 1-l, p2) # intersection
      angles.push self.class.calculate_polar_angle(s)
    end
    
    return angles.minmax
  end
  
  def self.calculate_polar_angle(vector)
    rho = Math::hypot(vector[0], vector[1])
    return Math::atan2(rho, vector[2])
  end
end

# from min max angles to hash interval
class PolarHashInterval < PolarMinMax
  attr_reader :hash_array
  
  def self.angular_resolution=(angular_resolution)
    @angular_resolution = to_radian(angular_resolution)
  end
  @angular_resolution = to_radian(10)
  
  def initialize(polygon)
    super(polygon)
    calculate_hash_array
  end
  
  def self.calculate_hash(vector)
    return self.as_hash(self.calculate_polar_angle(vector))
  end
  
  def self.as_hash(polar_angle)
    return (polar_angle/@angular_resolution).floor
  end
  
  def calculate_hash_array
    @hash_array = (self.class.as_hash(@pl_min)..self.class.as_hash(@pl_max)).to_a
  end
end

# determines range of azimuth angles covered by polygon
# if az_min>az_max the interval spans the 2pi angle
class AzimuthMinMax
  attr_reader :az_min, :az_max
  
  def initialize(polygon)
    @az_current = self.class.calculate_azimuth(polygon[0])
    @az_min = @az_max = @az_current
    @loop_number = 0 # how many times have we looped/ crossed 0=2pi border
    polygon.each {|p| add(p)}
    add(polygon[0]) # close the polygon
    adjust_interval
  end
  
  def self.calculate_azimuth(point)
    az = Math::atan2(point[1], point[0])
    if az>0
      return az
    else
      return az + 2*Math::PI
    end
  end
  
  # adding segments while keeping track of how many times we looped
  # @min is always smaller than @max here
  def add(point)
    az_new = self.class.calculate_azimuth(point)
    az_new += @loop_number * 2 * Math::PI
    
    # check if we looped
    if az_new-@az_current>Math::PI
      az_new -= 2*Math::PI
      @loop_number -= 1
    elsif @az_current-az_new>Math::PI
      az_new += 2*Math::PI
      @loop_number += 1
    end
    # save adjusted value
    @az_current = az_new
    
    # possibly extend borders
    @az_min = [@az_min, az_new].min
    @az_max = [@az_max, az_new].max
  end
  
  # after adding the whole polygon: get back in 0-2pi boundaries
  # now @az_max maybe smaller than @az_min, i.e. one looping
  def adjust_interval
    if @az_max - @az_min >= 2*Math::PI
      # have come full circle
      @az_min = 0
      @az_max = 2*Math::PI
    else
      @az_max %= 2*Math::PI
      @az_min %= 2*Math::PI
    end
  end
end

# from min max angles to hash interval
class AzimuthHashInterval < AzimuthMinMax
  attr_reader :hash_array
  
  def self.angular_resolution=(angular_resolution)
    @angular_resolution = to_radian(angular_resolution)
  end
  @angular_resolution = to_radian(10)
  
  def initialize(polygon)
    super(polygon)
    calculate_hash_array
  end
  
  def self.calculate_hash(point)
    return self.as_hash(self.calculate_azimuth(point))
  end
  
  def self.as_hash(az)
    return (az/@angular_resolution).floor
  end
  
  def calculate_hash_array
    if @az_min<=@az_max
      @hash_array = as_hash_array(@az_min, @az_max)
    else
      @hash_array = as_hash_array(0, @az_max) + as_hash_array(@az_min, 2*Math::PI)
    end
  end
  
  def as_hash_array(az1, az2)
    return (self.class.as_hash(az1)..self.class.as_hash(az2)).to_a
  end
end

# to debug the hash map
class HashMapVisualizationSphere
  
  def initialize(entities, center, map, az_resolution, pl_resolution, sun_transformation)
    @group = entities.add_group
    progress = Progress.new(360/az_resolution * 180/pl_resolution, 'Creating hash sphere...')
    @radius = 30
    ((az_resolution/2)..360).step(az_resolution) do |az|
      ((pl_resolution/2)..180).step(pl_resolution) do |pl|
        in_sun_coords = angles_to_vector(az, pl)
        in_local_coords = in_sun_coords.transform(sun_transformation.inverse)
        @group.entities.add_text(map.get_values(in_sun_coords).length.to_s, center + in_local_coords) 
        progress.work
      end
    end
  end
  
  def angles_to_vector(azimuth, polar)
    azimuth = to_radian(azimuth)
    polar = to_radian(polar)
    x = @radius * Math::sin(polar) * Math::cos(azimuth)
    y = @radius * Math::sin(polar) * Math::sin(azimuth)
    z = @radius * Math::cos(polar)
    return Geom::Vector3d.new(x,y,z)
  end
end