export type Point = { x: number; y: number };

type Callbacks = {
  // A pixel was picked, or null when the click landed off the board.
  onSelect: (pixel: Point | null) => void;
  // Enter or Space was pressed while the board had focus.
  onConfirm: () => void;
};

const MAX_SCALE = 48;
const DRAG_THRESHOLD = 5;

// Draws the board and handles zoom, pan and picking. The board itself lives
// in a small off-screen canvas, one canvas pixel per board pixel; the visible
// canvas shows it scaled, so a live update only ever touches one pixel.
export class BoardView {
  private readonly context: CanvasRenderingContext2D;
  private readonly buffer: HTMLCanvasElement;
  private readonly bufferContext: CanvasRenderingContext2D;
  private readonly image: ImageData;
  private readonly rgba: Uint32Array;
  private readonly paletteRgba: Uint32Array;
  private readonly observer: ResizeObserver;
  private readonly pointers = new Map<number, Point>();

  private scale = 1;
  private offsetX = 0;
  private offsetY = 0;
  private fitted = false;
  private dragged = false;
  private pinchDistance = 0;
  private selection: Point | null = null;
  private frame = 0;
  private dirty = false;

  constructor(
    private readonly canvas: HTMLCanvasElement,
    private readonly width: number,
    private readonly height: number,
    palette: string[],
    private readonly callbacks: Callbacks,
  ) {
    this.context = canvas.getContext("2d")!;
    this.buffer = document.createElement("canvas");
    this.buffer.width = width;
    this.buffer.height = height;
    this.bufferContext = this.buffer.getContext("2d")!;
    this.image = this.bufferContext.createImageData(width, height);
    this.rgba = new Uint32Array(this.image.data.buffer);
    this.paletteRgba = new Uint32Array(palette.map(toRgba));
    this.rgba.fill(this.paletteRgba[0]);

    canvas.addEventListener("pointerdown", this.onPointerDown);
    canvas.addEventListener("pointermove", this.onPointerMove);
    canvas.addEventListener("pointerup", this.onPointerUp);
    canvas.addEventListener("pointercancel", this.onPointerCancel);
    canvas.addEventListener("wheel", this.onWheel, { passive: false });
    canvas.addEventListener("keydown", this.onKeyDown);

    this.observer = new ResizeObserver(() => this.resize());
    this.observer.observe(canvas);
    this.resize();
  }

  destroy(): void {
    cancelAnimationFrame(this.frame);
    this.observer.disconnect();
    this.canvas.removeEventListener("pointerdown", this.onPointerDown);
    this.canvas.removeEventListener("pointermove", this.onPointerMove);
    this.canvas.removeEventListener("pointerup", this.onPointerUp);
    this.canvas.removeEventListener("pointercancel", this.onPointerCancel);
    this.canvas.removeEventListener("wheel", this.onWheel);
    this.canvas.removeEventListener("keydown", this.onKeyDown);
  }

  setBoard(colors: Uint8Array): void {
    for (let index = 0; index < colors.length; index++) {
      this.rgba[index] = this.paletteRgba[colors[index]];
    }
    this.dirty = true;
    this.requestDraw();
  }

  setPixel(x: number, y: number, color: number): void {
    this.rgba[y * this.width + x] = this.paletteRgba[color];
    this.dirty = true;
    this.requestDraw();
  }

  setSelection(pixel: Point | null): void {
    this.selection = pixel;
    this.requestDraw();
  }

  zoomBy(factor: number): void {
    const bounds = this.canvas.getBoundingClientRect();
    this.zoomAt(bounds.width / 2, bounds.height / 2, factor);
  }

  // Scales the board to fill the space above the tray, centred.
  fit(): void {
    const bounds = this.canvas.getBoundingClientRect();
    if (bounds.width === 0 || bounds.height === 0) return;

    const reservedBelow = Math.min(210, bounds.height * 0.34);
    const reservedAbove = 64;
    const availableHeight = Math.max(120, bounds.height - reservedBelow - reservedAbove);

    this.scale = Math.min((bounds.width - 32) / this.width, availableHeight / this.height);
    this.offsetX = (bounds.width - this.width * this.scale) / 2;
    this.offsetY = reservedAbove + (availableHeight - this.height * this.scale) / 2;
    this.fitted = true;
    this.requestDraw();
  }

  private get minScale(): number {
    const bounds = this.canvas.getBoundingClientRect();
    return Math.min(bounds.width / this.width, bounds.height / this.height) * 0.4;
  }

  private resize(): void {
    const bounds = this.canvas.getBoundingClientRect();
    const ratio = window.devicePixelRatio || 1;
    this.canvas.width = Math.max(1, Math.round(bounds.width * ratio));
    this.canvas.height = Math.max(1, Math.round(bounds.height * ratio));
    if (!this.fitted) this.fit();
    this.requestDraw();
  }

  private requestDraw(): void {
    cancelAnimationFrame(this.frame);
    this.frame = requestAnimationFrame(() => this.draw());
  }

  private draw(): void {
    if (this.dirty) {
      this.bufferContext.putImageData(this.image, 0, 0);
      this.dirty = false;
    }

    const ratio = window.devicePixelRatio || 1;
    const context = this.context;
    context.setTransform(1, 0, 0, 1, 0, 0);
    context.clearRect(0, 0, this.canvas.width, this.canvas.height);
    context.setTransform(ratio * this.scale, 0, 0, ratio * this.scale, ratio * this.offsetX, ratio * this.offsetY);

    // The sheet's shadow on the mat, then the sheet itself.
    context.fillStyle = "rgba(10, 30, 24, 0.35)";
    const lift = 6 / this.scale;
    context.fillRect(lift, lift, this.width, this.height);
    context.imageSmoothingEnabled = false;
    context.drawImage(this.buffer, 0, 0);

    if (this.selection) {
      const { x, y } = this.selection;
      const line = Math.max(1.5 / this.scale, 0.08);
      context.lineWidth = line * 2;
      context.strokeStyle = "#ffffff";
      context.strokeRect(x - line, y - line, 1 + line * 2, 1 + line * 2);
      context.lineWidth = line;
      context.strokeStyle = "#16231f";
      context.strokeRect(x - line * 1.5, y - line * 1.5, 1 + line * 3, 1 + line * 3);
    }
  }

  private zoomAt(screenX: number, screenY: number, factor: number): void {
    const next = Math.min(MAX_SCALE, Math.max(this.minScale, this.scale * factor));
    const applied = next / this.scale;
    this.offsetX = screenX - (screenX - this.offsetX) * applied;
    this.offsetY = screenY - (screenY - this.offsetY) * applied;
    this.scale = next;
    this.requestDraw();
  }

  private local(event: PointerEvent | WheelEvent): Point {
    const bounds = this.canvas.getBoundingClientRect();
    return { x: event.clientX - bounds.left, y: event.clientY - bounds.top };
  }

  private pixelAt(point: Point): Point | null {
    const x = Math.floor((point.x - this.offsetX) / this.scale);
    const y = Math.floor((point.y - this.offsetY) / this.scale);
    return x >= 0 && x < this.width && y >= 0 && y < this.height ? { x, y } : null;
  }

  private onPointerDown = (event: PointerEvent): void => {
    this.canvas.setPointerCapture(event.pointerId);
    this.pointers.set(event.pointerId, this.local(event));
    if (this.pointers.size === 1) this.dragged = false;
    if (this.pointers.size === 2) {
      this.dragged = true;
      this.pinchDistance = this.pointerSpread();
    }
  };

  private onPointerMove = (event: PointerEvent): void => {
    const previous = this.pointers.get(event.pointerId);
    if (!previous) return;

    const current = this.local(event);
    this.pointers.set(event.pointerId, current);

    if (this.pointers.size === 1) {
      const dx = current.x - previous.x;
      const dy = current.y - previous.y;
      if (!this.dragged && Math.hypot(dx, dy) < DRAG_THRESHOLD) {
        // Not a drag yet: keep the starting point so small jitters add up.
        this.pointers.set(event.pointerId, previous);
        return;
      }
      this.dragged = true;
      this.offsetX += dx;
      this.offsetY += dy;
      this.requestDraw();
    } else if (this.pointers.size === 2) {
      const spread = this.pointerSpread();
      const [first, second] = [...this.pointers.values()];
      if (this.pinchDistance > 0) {
        this.zoomAt((first.x + second.x) / 2, (first.y + second.y) / 2, spread / this.pinchDistance);
      }
      this.pinchDistance = spread;
    }
  };

  private onPointerUp = (event: PointerEvent): void => {
    const wasOnlyPointer = this.pointers.size === 1;
    const point = this.local(event);
    this.pointers.delete(event.pointerId);

    if (wasOnlyPointer && !this.dragged) {
      this.callbacks.onSelect(this.pixelAt(point));
    }
  };

  private onPointerCancel = (event: PointerEvent): void => {
    this.pointers.delete(event.pointerId);
  };

  private onWheel = (event: WheelEvent): void => {
    event.preventDefault();
    const point = this.local(event);
    this.zoomAt(point.x, point.y, Math.exp(-event.deltaY * 0.0015));
  };

  // Arrow keys move the selection one pixel, so the board works without a
  // pointer. Enter or Space places.
  private onKeyDown = (event: KeyboardEvent): void => {
    const steps: Record<string, Point> = {
      ArrowLeft: { x: -1, y: 0 },
      ArrowRight: { x: 1, y: 0 },
      ArrowUp: { x: 0, y: -1 },
      ArrowDown: { x: 0, y: 1 },
    };

    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      this.callbacks.onConfirm();
      return;
    }

    const step = steps[event.key];
    if (!step) return;

    event.preventDefault();
    const from = this.selection ?? { x: Math.floor(this.width / 2), y: Math.floor(this.height / 2) };
    this.callbacks.onSelect({
      x: Math.min(this.width - 1, Math.max(0, from.x + step.x)),
      y: Math.min(this.height - 1, Math.max(0, from.y + step.y)),
    });
  };

  private pointerSpread(): number {
    const [first, second] = [...this.pointers.values()];
    return Math.hypot(first.x - second.x, first.y - second.y);
  }
}

// "#RRGGBB" to the 32-bit value ImageData stores for an opaque pixel. Typed
// arrays are little-endian on every platform browsers run on, so the bytes
// land in memory as R, G, B, A.
function toRgba(hex: string): number {
  const value = Number.parseInt(hex.slice(1), 16);
  const red = (value >> 16) & 0xff;
  const green = (value >> 8) & 0xff;
  const blue = value & 0xff;
  return ((0xff << 24) | (blue << 16) | (green << 8) | red) >>> 0;
}
