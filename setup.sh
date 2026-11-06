#!/bin/bash
set -e
BASE="/workspaces/Fix/src/main/java/dev/kingcrystal"
R="/workspaces/Fix/src/main/resources"
mkdir -p $BASE/{config,event/events,gui,mixin,modules/{settings,hud},util} $R

cat > $BASE/event/Event.java << 'EOF'
package dev.kingcrystal.event;
public abstract class Event {
    private boolean cancelled = false;
    public boolean isCancelled() { return cancelled; }
    public void setCancelled(boolean b) { this.cancelled = b; }
}
EOF
cat > $BASE/event/EventHandler.java << 'EOF'
package dev.kingcrystal.event;
import java.lang.annotation.*;
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface EventHandler {}
EOF
cat > $BASE/event/EventBus.java << 'EOF'
package dev.kingcrystal.event;
import java.lang.reflect.Method;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
public class EventBus {
    private final Map<Class<?>, List<MethodEntry>> listeners = new ConcurrentHashMap<>();
    public void register(Object listener) {
        for (Method method : listener.getClass().getDeclaredMethods()) {
            if (method.isAnnotationPresent(EventHandler.class) && method.getParameterCount() == 1) {
                Class<?> eventType = method.getParameterTypes()[0];
                method.setAccessible(true);
                listeners.computeIfAbsent(eventType, k -> new ArrayList<>()).add(new MethodEntry(listener, method));
            }
        }
    }
    public void unregister(Object listener) { listeners.values().forEach(list -> list.removeIf(e -> e.listener == listener)); }
    public void post(Event event) {
        List<MethodEntry> entries = listeners.get(event.getClass());
        if (entries == null) return;
        for (MethodEntry entry : new ArrayList<>(entries)) { try { entry.method.invoke(entry.listener, event); } catch (Exception ignored) {} }
    }
    private record MethodEntry(Object listener, Method method) {}
}
EOF
cat > $BASE/event/events/TickEvent.java << 'EOF'
package dev.kingcrystal.event.events;
import dev.kingcrystal.event.Event;
public class TickEvent extends Event {}
EOF
cat > $BASE/event/events/RenderHudEvent.java << 'EOF'
package dev.kingcrystal.event.events;
import dev.kingcrystal.event.Event;
import net.minecraft.client.gui.DrawContext;
public class RenderHudEvent extends Event {
    private final DrawContext context;
    private final float tickDelta;
    public RenderHudEvent(DrawContext context, float tickDelta) { this.context = context; this.tickDelta = tickDelta; }
    public DrawContext getContext() { return context; }
    public float getTickDelta() { return tickDelta; }
}
EOF
cat > $BASE/event/events/RenderWorldEvent.java << 'EOF'
package dev.kingcrystal.event.events;
import dev.kingcrystal.event.Event;
import net.minecraft.client.render.Camera;
import net.minecraft.client.util.math.MatrixStack;
public class RenderWorldEvent extends Event {
    private final MatrixStack matrices;
    private final Camera camera;
    private final float tickDelta;
    public RenderWorldEvent(MatrixStack matrices, Camera camera, float tickDelta) { this.matrices = matrices; this.camera = camera; this.tickDelta = tickDelta; }
    public MatrixStack getMatrices() { return matrices; }
    public Camera getCamera() { return camera; }
    public float getTickDelta() { return tickDelta; }
}
EOF
cat > $BASE/modules/settings/Setting.java << 'EOF'
package dev.kingcrystal.modules.settings;
public abstract class Setting<T> {
    private final String name, description;
    private T value;
    public Setting(String name, String description, T defaultValue) { this.name = name; this.description = description; this.value = defaultValue; }
    public String getName() { return name; }
    public String getDescription() { return description; }
    public T getValue() { return value; }
    public void setValue(T value) { this.value = value; }
}
EOF
cat > $BASE/modules/settings/BooleanSetting.java << 'EOF'
package dev.kingcrystal.modules.settings;
public class BooleanSetting extends Setting<Boolean> {
    public BooleanSetting(String name, String description, boolean defaultValue) { super(name, description, defaultValue); }
    public void toggle() { setValue(!getValue()); }
}
EOF
cat > $BASE/modules/settings/SliderSetting.java << 'EOF'
package dev.kingcrystal.modules.settings;
public class SliderSetting extends Setting<Double> {
    private final double min, max, step;
    public SliderSetting(String name, String description, double defaultValue, double min, double max, double step) { super(name, description, defaultValue); this.min = min; this.max = max; this.step = step; }
    @Override public void setValue(Double value) { double c = Math.max(min, Math.min(max, value)); if (step > 0) c = Math.round(c / step) * step; super.setValue(c); }
    public double getPercent() { return max == min ? 0 : (getValue() - min) / (max - min); }
    public void setPercent(double p) { setValue(min + (max - min) * Math.max(0, Math.min(1, p))); }
    public double getMin() { return min; }
    public double getMax() { return max; }
}
EOF
cat > $BASE/modules/settings/ModeSetting.java << 'EOF'
package dev.kingcrystal.modules.settings;
import java.util.List;
public class ModeSetting extends Setting<String> {
    private final List<String> modes;
    public ModeSetting(String name, String description, String defaultValue, String... modes) { super(name, description, defaultValue); this.modes = List.of(modes); }
    public void cycle() { int i = modes.indexOf(getValue()); setValue(modes.get((i + 1) % modes.size())); }
    public List<String> getModes() { return modes; }
}
EOF
cat > $BASE/modules/settings/ColorSetting.java << 'EOF'
package dev.kingcrystal.modules.settings;
public class ColorSetting extends Setting<Integer> {
    public ColorSetting(String name, String description, int defaultValue) { super(name, description, defaultValue); }
}
EOF
cat > $BASE/modules/Module.java << 'EOF'
package dev.kingcrystal.modules;
import dev.kingcrystal.modules.settings.Setting;
import net.minecraft.client.MinecraftClient;
import java.util.*;
public abstract class Module {
    protected final MinecraftClient mc = MinecraftClient.getInstance();
    private final String name, description;
    private final Category category;
    private boolean enabled = false;
    private final List<Setting<?>> settings = new ArrayList<>();
    public enum Category {
        HUD("HUD"), COMBAT("Combat"), VISUAL("Visual"), MISC("Misc");
        private final String displayName;
        Category(String n) { this.displayName = n; }
        public String getDisplayName() { return displayName; }
    }
    public Module(String name, String description, Category category) { this.name = name; this.description = description; this.category = category; }
    protected <T extends Setting<?>> T addSetting(T s) { settings.add(s); return s; }
    public void toggle() { enabled = !enabled; if (enabled) onEnable(); else onDisable(); }
    public void onEnable() {}
    public void onDisable() {}
    public String getName() { return name; }
    public String getDescription() { return description; }
    public Category getCategory() { return category; }
    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean e) { this.enabled = e; }
    public List<Setting<?>> getSettings() { return settings; }
}
EOF
cat > $BASE/modules/ModuleManager.java << 'EOF'
package dev.kingcrystal.modules;
import dev.kingcrystal.KingCrystalClient;
import dev.kingcrystal.modules.hud.*;
import java.util.*;
import java.util.stream.Collectors;
public class ModuleManager {
    private final List<Module> modules = new ArrayList<>();
    public void registerModules() {
        register(new CrystalCounterModule());
        register(new CrystalHudModule());
        register(new TargetHudModule());
        register(new TotemCounterModule());
        register(new ArmorHudModule());
        register(new InventoryHudModule());
        register(new CpsCounterModule());
        register(new FpsDisplayModule());
        register(new PingDisplayModule());
        register(new KeybindHudModule());
        register(new CustomCrosshairModule());
        register(new CrystalVisualsModule());
        register(new DamageIndicatorModule());
    }
    private void register(Module m) { modules.add(m); KingCrystalClient.getInstance().getEventBus().register(m); }
    public void unregisterAll() { modules.forEach(m -> KingCrystalClient.getInstance().getEventBus().unregister(m)); }
    public List<Module> getModules() { return modules; }
    public List<Module> getModulesByCategory(Module.Category c) { return modules.stream().filter(m -> m.getCategory() == c).collect(Collectors.toList()); }
    public List<Module> search(String q) { String ql = q.toLowerCase(); return modules.stream().filter(m -> m.getName().toLowerCase().contains(ql)).collect(Collectors.toList()); }
    public Module getByName(String name) { return modules.stream().filter(m -> m.getName().equals(name)).findFirst().orElse(null); }
}
EOF
cat > $BASE/config/ConfigManager.java << 'EOF'
package dev.kingcrystal.config;
import com.google.gson.*;
import dev.kingcrystal.modules.Module;
import dev.kingcrystal.modules.ModuleManager;
import dev.kingcrystal.modules.settings.*;
import net.fabricmc.loader.api.FabricLoader;
import java.io.*;
import java.nio.file.*;
public class ConfigManager {
    private final Path configFile;
    private final Gson gson = new GsonBuilder().setPrettyPrinting().create();
    public ConfigManager() {
        Path configDir = FabricLoader.getInstance().getConfigDir().resolve("kingcrystal");
        try { Files.createDirectories(configDir); } catch (IOException ignored) {}
        this.configFile = configDir.resolve("modules.json");
    }
    public void save(ModuleManager manager) {
        JsonObject root = new JsonObject();
        for (Module module : manager.getModules()) {
            JsonObject obj = new JsonObject();
            obj.addProperty("enabled", module.isEnabled());
            JsonObject sets = new JsonObject();
            for (Setting<?> s : module.getSettings()) {
                if (s instanceof BooleanSetting b) sets.addProperty(s.getName(), b.getValue());
                else if (s instanceof SliderSetting sl) sets.addProperty(s.getName(), sl.getValue());
                else if (s instanceof ModeSetting m) sets.addProperty(s.getName(), m.getValue());
                else if (s instanceof ColorSetting c) sets.addProperty(s.getName(), c.getValue());
            }
            obj.add("settings", sets);
            root.add(module.getName(), obj);
        }
        try (Writer w = Files.newBufferedWriter(configFile)) { gson.toJson(root, w); } catch (IOException ignored) {}
    }
    public void load(ModuleManager manager) {
        if (!Files.exists(configFile)) return;
        try (Reader r = Files.newBufferedReader(configFile)) {
            JsonObject root = gson.fromJson(r, JsonObject.class);
            if (root == null) return;
            for (Module module : manager.getModules()) {
                if (!root.has(module.getName())) continue;
                JsonObject obj = root.getAsJsonObject(module.getName());
                if (obj.has("enabled")) module.setEnabled(obj.get("enabled").getAsBoolean());
                if (obj.has("settings")) {
                    JsonObject sets = obj.getAsJsonObject("settings");
                    for (Setting<?> s : module.getSettings()) {
                        if (!sets.has(s.getName())) continue;
                        if (s instanceof BooleanSetting b) b.setValue(sets.get(s.getName()).getAsBoolean());
                        else if (s instanceof SliderSetting sl) sl.setValue(sets.get(s.getName()).getAsDouble());
                        else if (s instanceof ModeSetting m) m.setValue(sets.get(s.getName()).getAsString());
                        else if (s instanceof ColorSetting c) c.setValue(sets.get(s.getName()).getAsInt());
                    }
                }
            }
        } catch (IOException ignored) {}
    }
}
EOF
cat > $BASE/util/RenderUtil.java << 'EOF'
package dev.kingcrystal.util;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
public class RenderUtil {
    public static void drawText(DrawContext ctx, String text, int x, int y, int color) { ctx.drawTextWithShadow(MinecraftClient.getInstance().textRenderer, text, x, y, color); }
    public static void drawTextCentered(DrawContext ctx, String text, int x, int y, int color) { int w = MinecraftClient.getInstance().textRenderer.getWidth(text); ctx.drawTextWithShadow(MinecraftClient.getInstance().textRenderer, text, x - w / 2, y, color); }
    public static void drawRoundedRect(DrawContext ctx, int x, int y, int w, int h, int radius, int color) { ctx.fill(x + radius, y, x + w - radius, y + h, color); ctx.fill(x, y + radius, x + radius, y + h - radius, color); ctx.fill(x + w - radius, y + radius, x + w, y + h - radius, color); }
    public static void drawGradientBorder(DrawContext ctx, int x, int y, int w, int h, int radius, int thick, int c1, int c2) { ctx.fillGradient(x, y, x + w, y + thick, c1, c2); ctx.fillGradient(x, y + h - thick, x + w, y + h, c1, c2); ctx.fill(x, y, x + thick, y + h, c1); ctx.fill(x + w - thick, y, x + w, y + h, c2); }
    public static void drawLine(DrawContext ctx, int x1, int y1, int x2, int y2, int color) { ctx.fill(x1, y1, x2, y2 + 1, color); }
    public static void drawCircle(DrawContext ctx, int cx, int cy, int r, int color) { ctx.fill(cx - r, cy - r, cx + r, cy + r, color); }
}
EOF
cat > $BASE/util/RenderUtil3D.java << 'EOF'
package dev.kingcrystal.util;
import com.mojang.blaze3d.systems.RenderSystem;
import net.minecraft.client.gl.ShaderProgramKeys;
import net.minecraft.client.render.*;
import net.minecraft.client.util.math.MatrixStack;
import org.joml.Matrix4f;
public class RenderUtil3D {
    public static void drawBoxOutline(MatrixStack matrices, double x1, double y1, double z1, double x2, double y2, double z2, int color, float lw) {
        RenderSystem.setShader(ShaderProgramKeys.POSITION_COLOR);
        RenderSystem.lineWidth(lw);
        RenderSystem.disableDepthTest();
        Tessellator t = Tessellator.getInstance();
        BufferBuilder buf = t.begin(VertexFormat.DrawMode.DEBUG_LINES, VertexFormats.POSITION_COLOR);
        Matrix4f m = matrices.peek().getPositionMatrix();
        float r = ((color >> 16) & 0xFF) / 255f, g = ((color >> 8) & 0xFF) / 255f, b = (color & 0xFF) / 255f, a = ((color >> 24) & 0xFF) / 255f;
        line(buf,m,x1,y1,z1,x2,y1,z1,r,g,b,a); line(buf,m,x2,y1,z1,x2,y1,z2,r,g,b,a); line(buf,m,x2,y1,z2,x1,y1,z2,r,g,b,a); line(buf,m,x1,y1,z2,x1,y1,z1,r,g,b,a);
        line(buf,m,x1,y2,z1,x2,y2,z1,r,g,b,a); line(buf,m,x2,y2,z1,x2,y2,z2,r,g,b,a); line(buf,m,x2,y2,z2,x1,y2,z2,r,g,b,a); line(buf,m,x1,y2,z2,x1,y2,z1,r,g,b,a);
        line(buf,m,x1,y1,z1,x1,y2,z1,r,g,b,a); line(buf,m,x2,y1,z1,x2,y2,z1,r,g,b,a); line(buf,m,x2,y1,z2,x2,y2,z2,r,g,b,a); line(buf,m,x1,y1,z2,x1,y2,z2,r,g,b,a);
        BufferRenderer.drawWithGlobalProgram(buf.end());
        RenderSystem.enableDepthTest();
        RenderSystem.lineWidth(1f);
    }
    private static void line(BufferBuilder b, Matrix4f m, double x1, double y1, double z1, double x2, double y2, double z2, float r, float g, float bl, float a) {
        b.vertex(m,(float)x1,(float)y1,(float)z1).color(r,g,bl,a); b.vertex(m,(float)x2,(float)y2,(float)z2).color(r,g,bl,a);
    }
}
EOF
cat > $BASE/mixin/MinecraftClientMixin.java << 'EOF'
package dev.kingcrystal.mixin;
import dev.kingcrystal.KingCrystalClient;
import net.minecraft.client.MinecraftClient;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;
@Mixin(MinecraftClient.class)
public class MinecraftClientMixin {
    @Inject(method = "tick", at = @At("HEAD"))
    private void onTick(CallbackInfo ci) { if (KingCrystalClient.getInstance() != null) KingCrystalClient.getInstance().onTick(); }
    @Inject(method = "stop", at = @At("HEAD"))
    private void onStop(CallbackInfo ci) { if (KingCrystalClient.getInstance() != null) KingCrystalClient.getInstance().getConfigManager().save(KingCrystalClient.getInstance().getModuleManager()); }
}
EOF
cat > $BASE/mixin/InGameHudMixin.java << 'EOF'
package dev.kingcrystal.mixin;
import dev.kingcrystal.KingCrystalClient;
import dev.kingcrystal.event.events.RenderHudEvent;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.hud.InGameHud;
import net.minecraft.client.render.RenderTickCounter;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;
@Mixin(InGameHud.class)
public class InGameHudMixin {
    @Inject(method = "render", at = @At("TAIL"))
    private void onRender(DrawContext context, RenderTickCounter tickCounter, CallbackInfo ci) {
        if (KingCrystalClient.getInstance() != null) KingCrystalClient.getInstance().getEventBus().post(new RenderHudEvent(context, tickCounter.getTickDelta(true)));
    }
}
EOF
cat > $BASE/mixin/GameRendererMixin.java << 'EOF'
package dev.kingcrystal.mixin;
import dev.kingcrystal.KingCrystalClient;
import dev.kingcrystal.event.events.RenderWorldEvent;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.render.Camera;
import net.minecraft.client.render.GameRenderer;
import net.minecraft.client.render.RenderTickCounter;
import net.minecraft.client.util.math.MatrixStack;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;
@Mixin(GameRenderer.class)
public class GameRendererMixin {
    @Inject(method = "renderWorld", at = @At("HEAD"))
    private void onRenderWorld(RenderTickCounter tickCounter, CallbackInfo ci) {
        if (KingCrystalClient.getInstance() == null) return;
        MinecraftClient mc = MinecraftClient.getInstance();
        if (mc.world == null || mc.player == null) return;
        KingCrystalClient.getInstance().getEventBus().post(new RenderWorldEvent(new MatrixStack(), mc.gameRenderer.getCamera(), tickCounter.getTickDelta(true)));
    }
}
EOF
cat > $BASE/modules/hud/FpsDisplayModule.java << 'EOF'
package dev.kingcrystal.modules.hud;
import dev.kingcrystal.event.EventHandler;
import dev.kingcrystal.event.events.RenderHudEvent;
import dev.kingcrystal.modules.Module;
import dev.kingcrystal.modules.settings.SliderSetting;
import dev.kingcrystal.util.RenderUtil;
public class FpsDisplayModule extends Module {
    private final SliderSetting x = addSetting(new SliderSetting("X","X pos",2,0,500,1));
    private final SliderSetting y = addSetting(new SliderSetting("Y","Y pos",2,0,500,1));
    public FpsDisplayModule() { super("FPS Display","Shows FPS",Category.HUD); }
    @EventHandler public void onRenderHud(RenderHudEvent e) {
        if (!isEnabled()) return;
        int fps = mc.getCurrentFps();
        RenderUtil.drawText(e.getContext(),"FPS: "+fps,(int)x.getValue(),(int)y.getValue(),fps>=60?0xFF55FF55:fps>=30?0xFFFFFF55:0xFFFF5555);
    }
}
EOF
cat > $BASE/modules/hud/PingDisplayModule.java << 'EOF'
package dev.kingcrystal.modules.hud;
import dev.kingcrystal.event.EventHandler;
import dev.kingcrystal.event.events.RenderHudEvent;
import dev.kingcrystal.modules.Module;
import dev.kingcrystal.modules.settings.SliderSetting;
import dev.kingcrystal.util.RenderUtil;
public class PingDisplayModule extends Module {
    private final SliderSetting x = addSetting(new SliderSetting("X","X pos",2,0,500,1));
    private final SliderSetting y = addSetting(new SliderSetting("Y","Y pos",12,0,500,1));
    public PingDisplayModule() { super("Ping Display","Shows ping",Category.HUD); }
    @EventHandler public void onRenderHud(RenderHudEvent e) {
        if (!isEnabled()||mc.player==null||mc.getNetworkHandler()==null) return;
        var entry = mc.getNetworkHandler().getPlayerListEntry(mc.player.getUuid());
        if (entry==null) return;
        int ping = entry.getLatency();
        RenderUtil.drawText(e.getContext(),"Ping: "+ping+"ms",(int)x.getValue(),(int)y.getValue(),ping<50?0xFF55FF55:ping<100?0xFFFFFF55:0xFFFF5555);
    }
}
EOF
cat > $BASE/modules/hud/CpsCounterModule.java << 'EOF'
package dev.kingcrystal.modules.hud;
import dev.kingcrystal.event.EventHandler;
import dev.kingcrystal.event.events.RenderHudEvent;
import dev.kingcrystal.event.events.TickEvent;
import dev.kingcrystal.modules.Module;
import dev.kingcrystal.modules.settings.SliderSetting;
import dev.kingcrystal.util.RenderUtil;
import java.util.*;
public class CpsCounterModule extends Module {
    private final SliderSetting x = addSetting(new SliderSetting("X","X pos",2,0,500,1));
    private final SliderSetting y = addSetting(new SliderSetting("Y","Y pos",22,0,500,1));
    private final Deque<Long> lc = new ArrayDeque<>(), rc = new ArrayDeque<>();
    public CpsCounterModule() { super("CPS Counter","Clicks per second",Category.HUD); }
    @EventHandler public void onTick(TickEvent e) {
        if (!isEnabled()) return;
        long now = System.currentTimeMillis();
        if (mc.options.attackKey.isPressed()) lc.add(now);
        if (mc.options.useKey.isPressed()) rc.add(now);
        lc.removeIf(t->now-t>1000); rc.removeIf(t->now-t>1000);
    }
    @EventHandler public void onRenderHud(RenderHudEvent e) {
        if (!isEnabled()) return;
        RenderUtil.drawText(e.getContext(),"CPS: "+lc.size()+" | "+rc.size(),(int)x.getValue(),(int)y.getValue(),0xFFFFFFFF);
    }
}
EOF
cat > $BASE/modules/hud/CrystalCounterModule.java << 'EOF'
package dev.kingcrystal.modules.hud;
import dev.kingcrystal.event.EventHandler;
import dev.kingcrystal.event.events.RenderHudEvent;
import dev.kingcrystal.modules.Module;
import dev.kingcrystal.modules.settings.SliderSetting;
import dev.kingcrystal.util.RenderUtil;
import net.minecraft.entity.decoration.EndCrystalEntity;
public class CrystalCounterModule extends Module {
    private final SliderSetting x = addSetting(new SliderSetting("X","X pos",2,0,500,1));
    private final SliderSetting y = addSetting(new SliderSetting("Y","Y pos",32,0,500,1));
    public CrystalCounterModule() { super("Crystal Counter","Counts End Crystals",Category.HUD); }
    @EventHandler public void onRenderHud(RenderHudEvent e) {
        if (!isEnabled()||mc.world==null||mc.player==null) return;
        long count = mc.world.getEntitiesByClass(EndCrystalEntity.class,mc.player.getBoundingBox().expand(64),en->true).size();
        RenderUtil.drawText(e.getContext(),"\u2b21 Crystals: "+count,(int)x.getValue(),(int)y.getValue(),0xFFFF55FF);
    }
}
EOF
cat > $BASE/modules/hud/TotemCounterModule.java << 'EOF'
package dev.kingcrystal.modules.hud;
import dev.kingcrystal.event.EventHandler;
import dev.kingcrystal.event.events.RenderHudEvent;
import dev.kingcrystal.modules.Module;
import dev.kingcrystal.modules.settings.SliderSetting;
import dev.kingcrystal.util.RenderUtil;
import net.minecraft.item.Items;
public class TotemCounterModule extends Module {
    private final SliderSetting x = addSetting(new SliderSetting("X","X pos",2,0,500,1));
    private final SliderSetting y = addSetting(new SliderSetting("Y","Y pos",42,0,500,1));
    public TotemCounterModule() { super("Totem Counter","Shows totem count",Category.HUD); }
    @EventHandler public void onRenderHud(RenderHudEvent e) {
        if (!isEnabled()||mc.player==null) return;
        long count = 0;
        for (int i=0;i<mc.player.getInventory().size();i++) if (mc.player.getInventory().getStack(i).getItem()==Items.TOTEM_OF_UNDYING) count++;
        RenderUtil.drawText(e.getContext(),"\u2764 Totems: "+count,(int)x.getValue(),(int)y.getValue(),count>2?0xFF55FF55:count==1?0xFFFFFF55:0xFFFF5555);
    }
}
EOF
cat > $BASE/modules/hud/ArmorHudModule.java << 'EOF'
package dev.kingcrystal.modules.hud;
import dev.kingcrystal.event.EventHandler;
import dev.kingcrystal.event.events.RenderHudEvent;
import dev.kingcrystal.modules.Module;
import dev.kingcrystal.modules.settings.SliderSetting;
import dev.kingcrystal.util.RenderUtil;
import net.minecraft.item.ItemStack;
public class ArmorHudModule extends Module {
    private final SliderSetting x = addSetting(new SliderSetting("X","X pos",2,0,500,1));
    private final SliderSetting y = addSetting(new SliderSetting("Y","Y pos",52,0,500,1));
    public ArmorHudModule() { super("Armor HUD","Shows armor durability",Category.HUD); }
    @EventHandler public void onRenderHud(RenderHudEvent e) {
        if (!isEnabled()||mc.player==null) return;
        int dy=(int)y.getValue();
        for (int i=3;i>=0;i--) {
            ItemStack stack=mc.player.getInventory().getArmorStack(i);
            if (stack.isEmpty()) continue;
            int dur=stack.getMaxDamage()-stack.getDamage(), max=stack.getMaxDamage(), pct=max==0?100:(dur*100/max);
            RenderUtil.drawText(e.getContext(),stack.getName().getString()+" "+dur+"/"+max,(int)x.getValue(),dy,pct>50?0xFF55FF55:pct>25?0xFFFFFF55:0xFFFF5555);
            dy+=10;
        }
    }
}
EOF
cat > $BASE/modules/hud/InventoryHudModule.java << 'EOF'
package dev.kingcrystal.modules.hud;
import dev.kingcrystal.event.EventHandler;
import dev.kingcrystal.event.events.RenderHudEvent;
import dev.kingcrystal.modules.Module;
import dev.kingcrystal.modules.settings.SliderSetting;
import dev.kingcrystal.util.RenderUtil;
public class InventoryHudModule extends Module {
    private final SliderSetting x = addSetting(new SliderSetting("X","X pos",2,0,500,1));
    private final SliderSetting y = addSetting(new SliderSetting("Y","Y pos",100,0,500,1));
    public InventoryHudModule() { super("Inventory HUD","Shows hotbar",Category.HUD); }
    @EventHandler public void onRenderHud(RenderHudEvent e) {
        if (!isEnabled()||mc.player==null) return;
        int dy=(int)y.getValue();
        for (int i=0;i<9;i++) {
            var stack=mc.player.getInventory().getStack(i);
            if (stack.isEmpty()) continue;
            String sel=mc.player.getInventory().selectedSlot==i?"\u00a7e> ":"\u00a77";
            RenderUtil.drawText(e.getContext(),sel+(i+1)+". "+stack.getName().getString()+" x"+stack.getCount(),(int)x.getValue(),dy,0xFFFFFFFF);
            dy+=10;
        }
    }
}
EOF
cat > $BASE/modules/hud/KeybindHudModule.java << 'EOF'
package dev.kingcrystal.modules.hud;
import dev.kingcrystal.KingCrystalClient;
import dev.kingcrystal.event.EventHandler;
import dev.kingcrystal.event.events.RenderHudEvent;
import dev.kingcrystal.modules.Module;
import dev.kingcrystal.modules.settings.SliderSetting;
import dev.kingcrystal.util.RenderUtil;
public class KeybindHudModule extends Module {
    private final SliderSetting x = addSetting(new SliderSetting("X","X pos",2,0,500,1));
    private final SliderSetting y = addSetting(new SliderSetting("Y","Y pos",200,0,500,1));
    public KeybindHudModule() { super("Keybind HUD","Active modules list",Category.HUD); }
    @EventHandler public void onRenderHud(RenderHudEvent e) {
        if (!isEnabled()) return;
        int dy=(int)y.getValue();
        for (Module m : KingCrystalClient.getInstance().getModuleManager().getModules()) {
            if (m.isEnabled()&&!(m instanceof KeybindHudModule)) { RenderUtil.drawText(e.getContext(),m.getName(),(int)x.getValue(),dy,0xFFAA00FF); dy+=10; }
        }
    }
}
EOF
cat > $BASE/modules/hud/TargetHudModule.java << 'EOF'
package dev.kingcrystal.modules.hud;
import dev.kingcrystal.event.EventHandler;
import dev.kingcrystal.event.events.RenderHudEvent;
import dev.kingcrystal.modules.Module;
import dev.kingcrystal.modules.settings.SliderSetting;
import dev.kingcrystal.util.RenderUtil;
import net.minecraft.entity.player.PlayerEntity;
import java.util.Comparator;
public class TargetHudModule extends Module {
    private final SliderSetting x = addSetting(new SliderSetting("X","X pos",2,0,500,1));
    private final SliderSetting y = addSetting(new SliderSetting("Y","Y pos",60,0,500,1));
    public TargetHudModule() { super("Target HUD","Nearest player info",Category.HUD); }
    @EventHandler public void onRenderHud(RenderHudEvent e) {
        if (!isEnabled()||mc.world==null||mc.player==null) return;
        mc.world.getPlayers().stream().filter(p->p!=mc.player).min(Comparator.comparingDouble(p->p.distanceTo(mc.player))).ifPresent(p -> {
            int px=(int)x.getValue(), py=(int)y.getValue();
            RenderUtil.drawText(e.getContext(),"\u00a7cTarget: \u00a7f"+p.getName().getString(),px,py,0xFFFFFFFF);
            RenderUtil.drawText(e.getContext(),"\u00a7cHP: \u00a7f"+String.format("%.1f",p.getHealth()),px,py+10,0xFFFFFFFF);
            RenderUtil.drawText(e.getContext(),"\u00a7cDist: \u00a7f"+String.format("%.1f",p.distanceTo(mc.player))+"m",px,py+20,0xFFFFFFFF);
        });
    }
}
EOF
cat > $BASE/modules/hud/CrystalHudModule.java << 'EOF'
package dev.kingcrystal.modules.hud;
import dev.kingcrystal.event.EventHandler;
import dev.kingcrystal.event.events.RenderHudEvent;
import dev.kingcrystal.modules.Module;
import dev.kingcrystal.modules.settings.SliderSetting;
import dev.kingcrystal.util.RenderUtil;
import net.minecraft.entity.decoration.EndCrystalEntity;
import net.minecraft.item.Items;
public class CrystalHudModule extends Module {
    private final SliderSetting x = addSetting(new SliderSetting("X","X pos",2,0,500,1));
    private final SliderSetting y = addSetting(new SliderSetting("Y","Y pos",80,0,500,1));
    public CrystalHudModule() { super("Crystal HUD","Crystal PvP panel",Category.HUD); }
    @EventHandler public void onRenderHud(RenderHudEvent e) {
        if (!isEnabled()||mc.world==null||mc.player==null) return;
        long crystals=mc.world.getEntitiesByClass(EndCrystalEntity.class,mc.player.getBoundingBox().expand(64),en->true).size();
        long obs=0,totems=0;
        for (int i=0;i<mc.player.getInventory().size();i++) { var s=mc.player.getInventory().getStack(i); if(s.getItem()==Items.OBSIDIAN) obs+=s.getCount(); if(s.getItem()==Items.TOTEM_OF_UNDYING) totems++; }
        RenderUtil.drawText(e.getContext(),"\u00a7d\u2b21 "+crystals+"  \u00a78Obs: \u00a7f"+obs+"  \u00a7c\u2764 "+totems,(int)x.getValue(),(int)y.getValue(),0xFFFFFFFF);
    }
}
EOF
cat > $BASE/modules/hud/CustomCrosshairModule.java << 'EOF'
package dev.kingcrystal.modules.hud;
import dev.kingcrystal.event.EventHandler;
import dev.kingcrystal.event.events.RenderHudEvent;
import dev.kingcrystal.modules.Module;
import dev.kingcrystal.modules.settings.*;
public class CustomCrosshairModule extends Module {
    private final ModeSetting style = addSetting(new ModeSetting("Style","Style","Cross","Cross","Dot","Circle","Plus"));
    private final SliderSetting size = addSetting(new SliderSetting("Size","Size",5,1,20,1));
    private final ColorSetting color = addSetting(new ColorSetting("Color","Color",0xFFFFFFFF));
    public CustomCrosshairModule() { super("Custom Crosshair","Custom crosshair",Category.VISUAL); }
    @EventHandler public void onRenderHud(RenderHudEvent e) {
        if (!isEnabled()) return;
        int sw=mc.getWindow().getScaledWidth(), sh=mc.getWindow().getScaledHeight();
        int cx=sw/2, cy=sh/2, s=(int)size.getValue(), c=color.getValue();
        switch(style.getValue()) {
            case "Cross","Plus" -> { e.getContext().fill(cx-s,cy-1,cx+s,cy+1,c); e.getContext().fill(cx-1,cy-s,cx+1,cy+s,c); }
            case "Dot" -> e.getContext().fill(cx-2,cy-2,cx+2,cy+2,c);
            case "Circle" -> { for(int i=0;i<360;i+=10){ double rad=Math.toRadians(i); int px=(int)(cx+s*Math.cos(rad)); int py=(int)(cy+s*Math.sin(rad)); e.getContext().fill(px-1,py-1,px+1,py+1,c); } }
        }
    }
}
EOF
cat > $BASE/modules/hud/CrystalVisualsModule.java << 'EOF'
package dev.kingcrystal.modules.hud;
import dev.kingcrystal.event.EventHandler;
import dev.kingcrystal.event.events.RenderWorldEvent;
import dev.kingcrystal.modules.Module;
import dev.kingcrystal.modules.settings.*;
import dev.kingcrystal.util.RenderUtil3D;
import net.minecraft.entity.decoration.EndCrystalEntity;
public class CrystalVisualsModule extends Module {
    private final ColorSetting color = addSetting(new ColorSetting("Color","ESP color",0xFFFF00FF));
    private final SliderSetting lineWidth = addSetting(new SliderSetting("Line Width","Width",1.5,0.5,5,0.5));
    public CrystalVisualsModule() { super("Crystal Visuals","ESP on End Crystals",Category.VISUAL); }
    @EventHandler public void onRenderWorld(RenderWorldEvent e) {
        if (!isEnabled()||mc.world==null||mc.player==null) return;
        var cam=e.getCamera().getPos();
        mc.world.getEntitiesByClass(EndCrystalEntity.class,mc.player.getBoundingBox().expand(64),en->true).forEach(crystal -> {
            double x=crystal.getX()-cam.x, y=crystal.getY()-cam.y, z=crystal.getZ()-cam.z;
            RenderUtil3D.drawBoxOutline(e.getMatrices(),x-0.5,y-0.5,z-0.5,x+0.5,y+1.5,z+0.5,color.getValue(),(float)lineWidth.getValue());
        });
    }
}
EOF
cat > $BASE/modules/hud/DamageIndicatorModule.java << 'EOF'
package dev.kingcrystal.modules.hud;
import dev.kingcrystal.event.EventHandler;
import dev.kingcrystal.event.events.RenderHudEvent;
import dev.kingcrystal.event.events.TickEvent;
import dev.kingcrystal.modules.Module;
import dev.kingcrystal.modules.settings.SliderSetting;
import dev.kingcrystal.util.RenderUtil;
import net.minecraft.entity.LivingEntity;
import java.util.*;
public class DamageIndicatorModule extends Module {
    private final SliderSetting duration = addSetting(new SliderSetting("Duration","Display ms",1500,500,5000,100));
    private final SliderSetting range = addSetting(new SliderSetting("Range","Range",20,1,50,1));
    private final Map<Integer,Float> lastHp = new HashMap<>();
    private final List<float[]> indicators = new ArrayList<>();
    public DamageIndicatorModule() { super("Damage Indicator","Floating damage numbers",Category.HUD); }
    @EventHandler public void onTick(TickEvent e) {
        if (!isEnabled()||mc.world==null||mc.player==null) return;
        long now=System.currentTimeMillis();
        mc.world.getEntitiesByClass(LivingEntity.class,mc.player.getBoundingBox().expand(range.getValue()),en->en!=mc.player).forEach(entity -> {
            Float last=lastHp.get(entity.getId()); float cur=entity.getHealth();
            if (last!=null&&last>cur) indicators.add(new float[]{(float)entity.getX(),(float)(entity.getY()+entity.getHeight()),(float)entity.getZ(),last-cur,now});
            lastHp.put(entity.getId(),cur);
        });
        indicators.removeIf(d->now-d[4]>duration.getValue());
    }
    @EventHandler public void onRenderHud(RenderHudEvent e) {
        if (!isEnabled()||mc.player==null) return;
        long now=System.currentTimeMillis();
        int sw=mc.getWindow().getScaledWidth(), sh=mc.getWindow().getScaledHeight();
        for (float[] ind : new ArrayList<>(indicators)) {
            float progress=(float)(now-ind[4])/(float)duration.getValue();
            int alpha=(int)((1f-progress)*255); if(alpha<=0) continue;
            double rx=ind[0]-mc.player.getX(), rz=ind[2]-mc.player.getZ();
            float yaw=(float)Math.toRadians(mc.player.getYaw());
            double sx=rx*Math.cos(yaw)-rz*Math.sin(-yaw), sz=rx*Math.sin(-yaw)+rz*Math.cos(yaw);
            if (sz>0.5) { int dx=sw/2+(int)(sx/sz*80); int dy=sh/2-(int)(30/sz)-(int)(progress*30); RenderUtil.drawText(e.getContext(),String.format("-%.1f",ind[3]),dx,dy,(alpha<<24)|0xFF3333); }
        }
    }
}
EOF
cat > $BASE/gui/ClickGUI.java << 'EOF'
package dev.kingcrystal.gui;
import dev.kingcrystal.KingCrystalClient;
import dev.kingcrystal.modules.Module;
import dev.kingcrystal.modules.settings.*;
import dev.kingcrystal.util.RenderUtil;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.text.Text;
import org.lwjgl.glfw.GLFW;
import java.util.*;
public class ClickGUI extends Screen {
    private final MinecraftClient client = MinecraftClient.getInstance();
    private static final int PX=20,PY=20,CW=100,CH=28,CG=4,MH=24,SH=20;
    private Module.Category selectedCat = Module.Category.HUD;
    private String searchQuery = "";
    private boolean searchFocused = false;
    private final Map<Module,Boolean> expanded = new HashMap<>();
    private int scrollOffset=0, maxScroll=0;
    private SliderSetting draggingSlider = null;
    private long openTime=0;
    private int ac1=0xFF8800FF, ac2=0xFF0088FF;
    public ClickGUI() { super(Text.literal("KingCrystal")); }
    @Override protected void init() { openTime=System.currentTimeMillis(); scrollOffset=0; }
    @Override public boolean shouldPause() { return false; }
    @Override public void render(DrawContext ctx, int mx, int my, float delta) {
        long elapsed=System.currentTimeMillis()-openTime;
        float prog=Math.min(1f,elapsed/200f);
        float eased=1f-(float)Math.pow(1-prog,4);
        int pa=(int)(0xFF*eased);
        ctx.fill(0,0,width,height,(int)(0x88*eased)<<24);
        int hw=width-40;
        RenderUtil.drawRoundedRect(ctx,PX,PY,hw,36,8,applyA(0xEE060612,pa));
        RenderUtil.drawGradientBorder(ctx,PX,PY,hw,36,8,1,applyA(ac1,pa),applyA(ac2,pa));
        RenderUtil.drawText(ctx,"\u00a75\u00a7l\u2b21 KingCrystal \u00a78v1.0",PX+8,PY+7,applyA(0xFFCCAAFF,pa));
        RenderUtil.drawText(ctx,"\u00a77FPS: \u00a7b"+client.getCurrentFps()+"  \u00a77MC: \u00a7b1.21.1",PX+8,PY+20,applyA(0xFFAAAAAA,pa));
        int sY=PY+44;
        RenderUtil.drawRoundedRect(ctx,PX,sY,300,20,4,applyA(0xCC0A0A14,pa));
        RenderUtil.drawGradientBorder(ctx,PX,sY,300,20,4,1,applyA(searchFocused?ac1:0x33888888,pa),applyA(searchFocused?ac2:0x33888888,pa));
        RenderUtil.drawText(ctx,searchQuery.isEmpty()&&!searchFocused?"\u00a77Search...":searchQuery+(searchFocused?"\u00a77|":""),PX+6,sY+6,applyA(0xFFFFFFFF,pa));
        int cY=PY+72;
        Module.Category[] cats=Module.Category.values();
        for (int i=0;i<cats.length;i++) {
            Module.Category cat=cats[i]; int cx2=PX+i*(CW+CG);
            boolean sel=cat==selectedCat&&searchQuery.isEmpty(), hov=mx>=cx2&&mx<cx2+CW&&my>=cY&&my<cY+CH;
            RenderUtil.drawRoundedRect(ctx,cx2,cY,CW,CH,5,sel?applyA(0xCC3D0066,pa):hov?applyA(0x661A0033,pa):applyA(0xCC0A0A14,pa));
            if(sel||hov) RenderUtil.drawGradientBorder(ctx,cx2,cY,CW,CH,5,1,applyA(ac1,pa),applyA(ac2,pa));
            RenderUtil.drawTextCentered(ctx,(sel?"\u00a7b":"\u00a77")+cat.getDisplayName(),cx2+CW/2,cY+10,applyA(0xFFFFFFFF,pa));
        }
        int mlY=cY+CH+8, mlH=height-mlY-20, mlW=220;
        RenderUtil.drawRoundedRect(ctx,PX,mlY,mlW,mlH,6,applyA(0xEE060612,pa));
        RenderUtil.drawGradientBorder(ctx,PX,mlY,mlW,mlH,6,1,applyA(ac1,100),applyA(ac2,100));
        List<Module> visible=searchQuery.isEmpty()?KingCrystalClient.getInstance().getModuleManager().getModulesByCategory(selectedCat):KingCrystalClient.getInstance().getModuleManager().search(searchQuery);
        ctx.enableScissor(PX+2,mlY+2,PX+mlW-2,mlY+mlH-2);
        int drawY=mlY+4-scrollOffset, totalH=0;
        for (Module mod : visible) {
            boolean hov=mx>=PX+2&&mx<PX+mlW-2&&my>=drawY&&my<drawY+MH;
            boolean exp=expanded.getOrDefault(mod,false);
            RenderUtil.drawRoundedRect(ctx,PX+2,drawY,mlW-4,MH-2,4,mod.isEnabled()?applyA(0xCC2D004D,pa):hov?applyA(0x661A0033,pa):applyA(0x220A0A14,pa));
            if(mod.isEnabled()) RenderUtil.drawGradientBorder(ctx,PX+2,drawY,mlW-4,MH-2,4,1,applyA(ac1,pa),applyA(ac2,pa));
            RenderUtil.drawText(ctx,(mod.isEnabled()?"\u00a7b":"\u00a77")+mod.getName(),PX+8,drawY+7,applyA(0xFFFFFFFF,pa));
            if(!mod.getSettings().isEmpty()) RenderUtil.drawText(ctx,exp?"\u00a77\u25be":"\u00a77\u25b8",PX+mlW-14,drawY+7,applyA(0xFF888888,pa));
            drawY+=MH; totalH+=MH;
            if(exp) { for(Setting<?> s:mod.getSettings()){drawSetting(ctx,s,PX+4,drawY,mlW-8,mx,my,pa);drawY+=SH+2;totalH+=SH+2;} }
        }
        maxScroll=Math.max(0,totalH-mlH+8);
        ctx.disableScissor();
        RenderUtil.drawText(ctx,"\u00a78[C] Color  [ESC] Close",PX,height-14,applyA(0xFF555577,pa));
        super.render(ctx,mx,my,delta);
    }
    private void drawSetting(DrawContext ctx, Setting<?> s, int x, int y, int w, int mx, int my, int pa) {
        if(s instanceof BooleanSetting b){RenderUtil.drawRoundedRect(ctx,x,y,w,SH-1,3,applyA(0x33222222,pa));RenderUtil.drawText(ctx,"\u00a77"+s.getName(),x+4,y+5,applyA(0xFFBBBBBB,pa));int tx=x+w-26;RenderUtil.drawRoundedRect(ctx,tx,y+4,22,11,5,applyA(b.getValue()?ac1:0xFF444444,pa));RenderUtil.drawRoundedRect(ctx,b.getValue()?tx+12:tx+1,y+5,9,9,4,applyA(0xFFFFFFFF,pa));}
        else if(s instanceof SliderSetting sl){RenderUtil.drawRoundedRect(ctx,x,y,w,SH-1,3,applyA(0x33222222,pa));RenderUtil.drawText(ctx,"\u00a77"+s.getName()+": \u00a7b"+String.format("%.1f",sl.getValue()),x+4,y+5,applyA(0xFFBBBBBB,pa));int bx=x+4,bw=w-8,filled=(int)(bw*sl.getPercent());RenderUtil.drawRoundedRect(ctx,bx,y+14,bw,3,1,applyA(0xFF222222,pa));if(filled>0)RenderUtil.drawRoundedRect(ctx,bx,y+14,filled,3,1,applyA(ac1,pa));}
        else if(s instanceof ModeSetting m){RenderUtil.drawRoundedRect(ctx,x,y,w,SH-1,3,applyA(0x33222222,pa));RenderUtil.drawText(ctx,"\u00a77"+s.getName(),x+4,y+5,applyA(0xFFBBBBBB,pa));RenderUtil.drawText(ctx,"\u00a7b"+m.getValue(),x+w-60,y+5,applyA(0xFFCCAAFF,pa));}
        else if(s instanceof ColorSetting c){RenderUtil.drawRoundedRect(ctx,x,y,w,SH-1,3,applyA(0x33222222,pa));RenderUtil.drawText(ctx,"\u00a77"+s.getName(),x+4,y+5,applyA(0xFFBBBBBB,pa));RenderUtil.drawRoundedRect(ctx,x+w-18,y+3,14,13,3,c.getValue());}
    }
    @Override public boolean mouseClicked(double mouseX, double mouseY, int button) {
        int mx=(int)mouseX, my=(int)mouseY, sY=PY+44;
        if(mx>=PX&&mx<PX+300&&my>=sY&&my<sY+20){searchFocused=true;return true;}else searchFocused=false;
        int cY=PY+72; Module.Category[] cats=Module.Category.values();
        for(int i=0;i<cats.length;i++){int cx2=PX+i*(CW+CG);if(mx>=cx2&&mx<cx2+CW&&my>=cY&&my<cY+CH){selectedCat=cats[i];searchQuery="";scrollOffset=0;return true;}}
        int mlY=cY+CH+8, mlH=height-mlY-20, mlW=220;
        if(mx>=PX&&mx<PX+mlW&&my>=mlY&&my<mlY+mlH){
            List<Module> visible=searchQuery.isEmpty()?KingCrystalClient.getInstance().getModuleManager().getModulesByCategory(selectedCat):KingCrystalClient.getInstance().getModuleManager().search(searchQuery);
            int drawY=mlY+4-scrollOffset;
            for(Module mod:visible){
                if(my>=drawY&&my<drawY+MH){if(button==0)mod.toggle();else if(button==1)expanded.put(mod,!expanded.getOrDefault(mod,false));return true;}
                drawY+=MH;
                if(expanded.getOrDefault(mod,false)){for(Setting<?> s:mod.getSettings()){if(my>=drawY&&my<drawY+SH+2){handleSettingClick(s,mx,my,drawY,PX+4,mlW-8,button);return true;}drawY+=SH+2;}}
            }
        }
        return super.mouseClicked(mouseX,mouseY,button);
    }
    private void handleSettingClick(Setting<?> s, int mx, int my, int drawY, int x, int w, int button){
        if(s instanceof BooleanSetting b){if(mx>=x+w-26&&mx<x+w-4)b.toggle();}
        else if(s instanceof ModeSetting m)m.cycle();
        else if(s instanceof SliderSetting sl){int bx=x+4,bw=w-8;if(my>=drawY+10){draggingSlider=sl;sl.setPercent((double)(mx-bx)/bw);}}
        KingCrystalClient.getInstance().getConfigManager().save(KingCrystalClient.getInstance().getModuleManager());
    }
    @Override public boolean mouseDragged(double mx, double my, int button, double dx, double dy){if(draggingSlider!=null)draggingSlider.setPercent(Math.max(0,Math.min(1,(mx-PX-8)/(220-16))));return super.mouseDragged(mx,my,button,dx,dy);}
    @Override public boolean mouseReleased(double mx, double my, int button){draggingSlider=null;return super.mouseReleased(mx,my,button);}
    @Override public boolean mouseScrolled(double mx, double my, double h, double v){scrollOffset=Math.max(0,Math.min(maxScroll,scrollOffset-(int)(v*15)));return true;}
    @Override public boolean keyPressed(int key, int scan, int mods){
        if(key==GLFW.GLFW_KEY_ESCAPE){close();return true;}
        if(searchFocused&&key==GLFW.GLFW_KEY_BACKSPACE&&!searchQuery.isEmpty()){searchQuery=searchQuery.substring(0,searchQuery.length()-1);return true;}
        return super.keyPressed(key,scan,mods);
    }
    @Override public boolean charTyped(char c, int mods){
        if(searchFocused){searchQuery+=c;return true;}
        if(c=='c'||c=='C'){int[][]themes={{0xFF8800FF,0xFF0088FF},{0xFF00FFCC,0xFF0044FF},{0xFFFF0066,0xFFFF8800},{0xFF00FF44,0xFF00CCFF}};int cur=0;for(int i=0;i<themes.length;i++)if(themes[i][0]==ac1){cur=i;break;}int n=(cur+1)%themes.length;ac1=themes[n][0];ac2=themes[n][1];return true;}
        return super.charTyped(c,mods);
    }
    private static int applyA(int color, int alpha){int ba=(color>>24)&0xFF;int na=(int)(ba*(alpha/255f));return(na<<24)|(color&0x00FFFFFF);}
}
EOF
cat > $BASE/KingCrystalClient.java << 'EOF'
package dev.kingcrystal;
import dev.kingcrystal.config.ConfigManager;
import dev.kingcrystal.event.EventBus;
import dev.kingcrystal.event.events.TickEvent;
import dev.kingcrystal.gui.ClickGUI;
import dev.kingcrystal.modules.ModuleManager;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;
public class KingCrystalClient implements ClientModInitializer {
    private static KingCrystalClient INSTANCE;
    private EventBus eventBus;
    private ModuleManager moduleManager;
    private ConfigManager configManager;
    @Override
    public void onInitializeClient() {
        INSTANCE = this;
        eventBus = new EventBus();
        moduleManager = new ModuleManager();
        configManager = new ConfigManager();
        moduleManager.registerModules();
        configManager.load(moduleManager);
        KeyBinding guiKey = KeyBindingHelper.registerKeyBinding(new KeyBinding("key.kingcrystal.gui", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_RIGHT_SHIFT, "KingCrystal"));
        ClientTickEvents.END_CLIENT_TICK.register(client -> { while(guiKey.wasPressed()){if(client.currentScreen==null)client.setScreen(new ClickGUI());else if(client.currentScreen instanceof ClickGUI)client.setScreen(null);}});
    }
    public void onTick() { eventBus.post(new TickEvent()); }
    public static KingCrystalClient getInstance() { return INSTANCE; }
    public EventBus getEventBus() { return eventBus; }
    public ModuleManager getModuleManager() { return moduleManager; }
    public ConfigManager getConfigManager() { return configManager; }
}
EOF
cat > $R/fabric.mod.json << 'EOF'
{
  "schemaVersion": 1,
  "id": "kingcrystal",
  "version": "${version}",
  "name": "KingCrystal Client",
  "description": "Professional Crystal PvP client for Minecraft 1.21.1",
  "authors": ["KingCrystal"],
  "license": "MIT",
  "environment": "client",
  "entrypoints": {"client": ["dev.kingcrystal.KingCrystalClient"]},
  "mixins": ["kingcrystal.mixins.json"],
  "depends": {"fabricloader": ">=0.14.0","minecraft": "~1.21.1","java": ">=21","fabric-api": "*"}
}
EOF
cat > $R/kingcrystal.mixins.json << 'EOF'
{
  "required": true,
  "package": "dev.kingcrystal.mixin",
  "compatibilityLevel": "JAVA_21",
  "client": ["GameRendererMixin","InGameHudMixin","MinecraftClientMixin"],
  "injectors": {"defaultRequire": 1}
}
EOF
echo "=== DONE: $(find /workspaces/Fix/src -name '*.java' | wc -l) Java files created ==="
