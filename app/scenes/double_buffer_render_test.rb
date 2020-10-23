# Demonstration of the performance improvement by using the double buffering technique for RenderTargets
class DoubleBufferRenderTest < Zif::Scene
  include Zif::Traceable

  attr_accessor :map, :tiles

  def initialize
    @tracer_service_name = :tracer
    # Turn the threshold down to see a breakdown of performance:
    # tracer.time_threshold = 0.002

    mark('#initialize: Begin')

    @map = Zif::LayeredTileMap.new('double_buffered_test', 64, 64, 20, 12)
    @map.new_simple_layer(:fully_rerender)
    @map.new_simple_layer(:double_buffered_rerender)

    @map.layers[:fully_rerender].source_sprites = initialize_sprites('full')
    @map.layers[:double_buffered_rerender].source_sprites = initialize_sprites('double_buffered', 1)

    @rendering = true
    @full_render = false
    @never_rendered = true
    mark('#initialize: Finished')
  end

  def initialize_sprites(name, page=0)
    992.times.map do |i|
      y_i, x_i = i.divmod(32)
      $game.services[:sprite_registry].construct(:white_1).tap do |s|
        s.name = "#{name}_#{x_i}_#{y_i}"
        s.b = page.zero? ? 200 : 0
        s.r = 100 + x_i
        s.g = 100 + y_i
        s.x = (x_i * (16+1)) + (page * 640) + 50
        s.y = (y_i * (16+1)) + 70
        s.w = 16
        s.h = 16
      end
    end
  end

  def prepare_scene
    $game.services[:action_service].reset_actionables
    $game.services[:input_service].reset
    $gtk.args.outputs.static_sprites.clear
    $gtk.args.outputs.static_labels.clear
    cs = @map.layer_containing_sprites
    $gtk.args.outputs.static_sprites << cs
    @scene_timer = 60 * 60 * 1
  end

  def perform_tick
    mark('#perform_tick: Begin')

    $gtk.args.outputs.background_color = [0, 0, 0, 0]
    mark('#perform_tick: Init')

    @full_render = !@full_render if $gtk.args.inputs.keyboard.key_up.x
    @rendering   = !@rendering if $gtk.args.inputs.keyboard.key_up.z

    rerender_focus
    mark('#perform_tick: rerender_focus')

    perform_tick_debug_labels

    mark('#perform_tick: Finished')

    @scene_timer -= 1
    return :ui_sample if $gtk.args.inputs.keyboard.key_up.space || @scene_timer.zero?
  end

  def rerender_focus
    if @rendering
      cur_layer = @full_render ? :fully_rerender : :double_buffered_rerender
      s = @map.layers[cur_layer].source_sprites.sample
      s.r, s.g, s.b = Zif.hsv_to_rgb($gtk.args.tick_count % 360, 100, 100)

      # This is the magic.
      @map.layers[cur_layer].rerender_rect = s.rect if (cur_layer == :double_buffered_rerender) && !@never_rendered
    end

    @map.layers[:fully_rerender].should_render           = @never_rendered || (@rendering && @full_render)
    @map.layers[:double_buffered_rerender].should_render = @never_rendered || (@rendering && !@full_render)

    mark('#rerender_focus: Setup')
    @map.refresh
    mark('#rerender_focus: Refresh')
    @never_rendered = false
  end

  # rubocop:disable Layout/LineLength
  # rubocop:disable Style/NestedTernaryOperator
  def perform_tick_debug_labels
    color = {r: 255, g: 255, b: 255, a: 255}
    active_color = {r: 255, g: 0, b: 0, a: 255}
    $gtk.args.outputs.labels << { x: 8, y: 720 - 8, text: "#{self.class.name}.  Press spacebar to transition to next scene, or wait #{@scene_timer} ticks." }.merge(color)
    $gtk.args.outputs.labels << { x: 8, y: 720 - 28, text: "#{tracer&.last_tick_ms} #{$gtk.args.gtk.current_framerate}fps" }.merge(color)
    $gtk.args.outputs.labels << { x: 8, y: 720 - 48, text: "Render mode (press X to change, Z for off): #{@rendering ? (@full_render ? 'Full re-render' : 'Double buffer re-render') : 'Off'}" }.merge(color)

    $gtk.args.outputs.labels << { x: 50,  y: 720 - 100, text: 'Full re-render' }.merge(@rendering && @full_render ? active_color : color)
    $gtk.args.outputs.labels << { x: 690, y: 720 - 100, text: 'Double buffered re-render' }.merge(@rendering && !@full_render ? active_color : color)

    $gtk.args.outputs.labels << { x: 8, y: 60, text: "Last slowest mark: #{tracer&.slowest_mark}" }.merge(color)
  end
  # rubocop:enable Layout/LineLength
  # rubocop:enable Style/NestedTernaryOperator
end
