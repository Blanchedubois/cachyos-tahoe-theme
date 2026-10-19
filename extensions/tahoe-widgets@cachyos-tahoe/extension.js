// Tahoe Widgets: Liquid Glass widgets on the desktop layer, above the wallpaper and below windows.
//
// The glass behind each widget is the wallpaper only, so it is a static copy of it, clipped to the
// widget and run through a Blur My Shell pipeline (the same Liquid Glass recipe as the Dock).
// It repaints only when the wallpaper or the mode changes. Without Blur My Shell each widget falls
// back to a plain translucent card.

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import {ExtensionState} from 'resource:///org/gnome/shell/misc/extensionUtils.js';

const BMS_UUID = 'blur-my-shell@aunetx';
const PIPELINE = 'pipeline_glassbar_dock';
const STATE_FILE = GLib.build_filenamev([GLib.get_user_config_dir(), 'tahoe-glass', 'state']);
const RADIUS = 24;     // Tahoe widget corners, logical px
const SMALL = 170;     // Tahoe small widget, logical px

// light | dark | milky, as glass-bar.sh last set it
function glassMode() {
    try {
        const [, bytes] = GLib.file_get_contents(STATE_FILE);
        const lines = new TextDecoder().decode(bytes).split('\n');
        const mode = lines.filter(l => l.startsWith('mode=')).pop()?.slice(5);
        return ['light', 'dark', 'milky'].includes(mode) ? mode : 'milky';
    } catch {
        return 'milky';
    }
}

// Blur My Shell's own modules, so the widgets share its pipelines and their live settings
async function loadBms() {
    const ext = Main.extensionManager.lookup(BMS_UUID);
    if (ext?.state !== ExtensionState.ACTIVE || !global.blur_my_shell)
        return null;
    const base = `file://${ext.path}`;
    const [{Pipeline}, {RoundedPipeline}] = await Promise.all([
        import(`${base}/pipelines/pipeline.js`),
        import(`${base}/render/rounded_pipeline.js`),
    ]);
    return {Pipeline, RoundedPipeline, bms: global.blur_my_shell};
}

class GlassTile {
    constructor(monitorIndex, x, y, width, height) {
        this._monitorIndex = monitorIndex;
        this._rect = {x, y, width, height};
        this._glass = null;

        this.actor = new St.Widget({
            style_class: 'tahoe-widget',
            layout_manager: new Clutter.BinLayout(),
            clip_to_allocation: false,
        });
        this._backdrop = new Meta.BackgroundGroup({name: 'tahoe-widget-backdrop'});
        this.actor.add_child(this._backdrop);
        this._content = new St.BoxLayout({
            style_class: 'tahoe-widget-content',
            orientation: Clutter.Orientation.VERTICAL,
            x_expand: true, y_expand: true,
        });
        this.actor.add_child(this._content);

        this._time = new St.Label({style_class: 'tahoe-widget-time'});
        this._date = new St.Label({style_class: 'tahoe-widget-date'});
        this._content.add_child(this._date);
        this._content.add_child(this._time);
        this._tick();
        this._timer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => {
            this._tick();
            return GLib.SOURCE_CONTINUE;
        });

        this.place();
    }

    _tick() {
        const now = GLib.DateTime.new_now_local();
        this._time.text = now.format('%H:%M');
        this._date.text = now.format('%A %e').replace(/\s+/g, ' ').toUpperCase();
    }

    place() {
        const monitor = Main.layoutManager.monitors[this._monitorIndex];
        const scale = St.ThemeContext.get_for_stage(global.stage).scale_factor;
        const {x, y, width, height} = this._rect;
        this.actor.set_position(monitor.x + x * scale, monitor.y + y * scale);
        this.actor.set_size(width * scale, height * scale);
        if (this._glass) {
            // the wallpaper copy covers the whole monitor: show only the part under the widget
            const bg = this._glass.background;
            bg.set_position(-x * scale, -y * scale);
            bg.set_clip(x * scale, y * scale, width * scale, height * scale);
        }
    }

    setGlass(lib) {
        this.clearGlass();
        if (!lib) {
            this.actor.add_style_class_name('tahoe-widget-fallback');
            return;
        }
        this.actor.remove_style_class_name('tahoe-widget-fallback');
        const {Pipeline, RoundedPipeline, bms} = lib;
        const pipeline = new Pipeline(bms._effects_manager, bms._pipelines_manager, PIPELINE);
        const managers = [];
        const background = pipeline.create_background_with_effects(
            this._monitorIndex, managers, this._backdrop, 'tahoe-widget-glass', false);
        const rounded = new RoundedPipeline(bms._effects_manager, () => RADIUS, () => 0);
        rounded.bind(pipeline, background);
        this._glass = {pipeline, background, managers, rounded};
        this.place();
    }

    clearGlass() {
        if (!this._glass)
            return;
        const {pipeline, background, managers, rounded} = this._glass;
        this._glass = null;
        rounded.destroy();
        managers.forEach(m => m.destroy());
        pipeline.destroy();
        background.destroy();
    }

    setMode(mode) {
        for (const m of ['light', 'dark', 'milky'])
            this.actor.remove_style_class_name(`tahoe-widget-${m}`);
        this.actor.add_style_class_name(`tahoe-widget-${mode}`);
    }

    destroy() {
        GLib.source_remove(this._timer);
        this.clearGlass();
        this.actor.destroy();
    }
}

export default class TahoeWidgets extends Extension {
    enable() {
        this._tiles = [new GlassTile(Main.layoutManager.primaryIndex, 40, 60, SMALL, SMALL)];
        // above the wallpaper, below every window
        this._tiles.forEach(t => Main.layoutManager._backgroundGroup.add_child(t.actor));

        this._applyMode();
        this._stateMonitor = Gio.File.new_for_path(STATE_FILE).monitor_file(Gio.FileMonitorFlags.NONE, null);
        this._stateMonitor.connect('changed', () => this._applyMode());

        Main.layoutManager.connectObject('monitors-changed', () => this._rebuildGlass(), this);
        // Blur My Shell restarts around the lock screen: rebuild on its new managers
        Main.extensionManager.connectObject('extension-state-changed', (_m, ext) => {
            if (ext.uuid === BMS_UUID)
                this._rebuildGlass();
        }, this);
        this._rebuildGlass();
    }

    _applyMode() {
        const mode = glassMode();
        this._tiles?.forEach(t => t.setMode(mode));
    }

    async _rebuildGlass() {
        const serial = this._serial = (this._serial ?? 0) + 1;
        let lib = null;
        try {
            lib = await loadBms();
        } catch (e) {
            console.warn(`tahoe-widgets: Blur My Shell glass unavailable: ${e}`);
        }
        if (serial !== this._serial || !this._tiles)
            return;
        this._tiles.forEach(t => t.setGlass(lib));
    }

    disable() {
        this._serial = (this._serial ?? 0) + 1;
        Main.layoutManager.disconnectObject(this);
        Main.extensionManager.disconnectObject(this);
        this._stateMonitor?.cancel();
        this._stateMonitor = null;
        this._tiles.forEach(t => t.destroy());
        this._tiles = null;
    }
}
