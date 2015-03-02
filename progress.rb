
class Progress
  def initialize(total_work, label)
    @label = label
    @total_work = total_work
    @current_work = 0
    @current_percent = 0
    @start_time = Time.new
  end
  
  def work
    @current_work += 1
    percent = 100 * @current_work / @total_work
    if percent!=@current_percent
      if percent%5<@current_percent%5
        Sketchup.active_model.active_view.refresh
      end
      @current_percent = percent
      current_time = Time.new - @start_time
      time_left = current_time.to_i * (100 - percent) / (percent) 
      Sketchup.status_text = "#{@label} #{percent}% done, #{time_left}s left"
    end
  end
end
