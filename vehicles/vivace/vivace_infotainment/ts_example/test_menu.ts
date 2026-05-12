/// <reference path="../../../../ui/modules/beamng.d.ts" />

import { vehicleData } from "./vehicleData";

let currentPage = "home";
const menuItems = document.querySelectorAll<HTMLElement>(".menu-item");
const contentBodies = document.querySelectorAll<HTMLElement>(".content-body");
const actionButtons = document.querySelectorAll<HTMLElement>(".action-button");
const backButton = document.getElementById("back-btn")!;
const coordX = document.getElementById("coord-x")!;
const coordY = document.getElementById("coord-y")!;
const pixelX = document.getElementById("pixel-x")!;
const pixelY = document.getElementById("pixel-y")!;
const eventType = document.getElementById("event-type")!;
const lastAction = document.getElementById("last-action")!;

const originalOnInput = window.screenInput.onInput;
window.screenInput.onInput = function (eventData) {
  coordX.textContent = (eventData.x || 0).toFixed(3);
  coordY.textContent = (eventData.y || 0).toFixed(3);
  pixelX.textContent = String(eventData.pixelX || Math.floor(eventData.x * 1024));
  pixelY.textContent = String(eventData.pixelY || Math.floor(eventData.y * 512));
  eventType.textContent = eventData.type || "none";
  if (originalOnInput) originalOnInput(eventData);
};

const scrollContainer = document.getElementById("scroll-test");
if (scrollContainer) {
  let scrollDragActive = false;
  let lastScrollY = 0;

  scrollContainer.addEventListener("mousedown", (e: MouseEvent) => {
    scrollDragActive = true;
    lastScrollY = e.clientY;
  });
  document.addEventListener("mousemove", (e: MouseEvent) => {
    if (!scrollDragActive) return;
    const deltaY = e.clientY - lastScrollY;
    lastScrollY = e.clientY;
    scrollContainer.scrollTop -= deltaY;
    lastAction.textContent = "Drag scroll";
  });
  document.addEventListener("mouseup", () => {
    scrollDragActive = false;
  });
  scrollContainer.addEventListener("wheel", (e: any) => {
    lastAction.textContent = `Scrolled: ${e.deltaY.toFixed(0)}`;
  });
}

function navigateTo(page: string) {
  currentPage = page;
  menuItems.forEach((item) => {
    item.dataset.page === page ? item.classList.add("active") : item.classList.remove("active");
  });
  contentBodies.forEach((body) => {
    body.dataset.page === page ? body.classList.add("active") : body.classList.remove("active");
  });
  lastAction.textContent = `Nav: ${page}`;
}

menuItems.forEach((item) => {
  item.addEventListener("click", () => navigateTo(item.dataset.page!));
});

actionButtons.forEach((button) => {
  button.addEventListener("click", () => {
    button.classList.toggle("selected");
    lastAction.textContent = button.dataset.action!;
  });
});

const draggableBoxes = document.querySelectorAll<HTMLElement>(".draggable-box");
const boxPos: Record<string, { x: number; y: number }> = {};
let activeDragBox: HTMLElement | null = null;
let activeDragBoxId: string | null = null;
let lastDragX = 0;
let lastDragY = 0;

draggableBoxes.forEach((box) => {
  const id = box.dataset.box!;
  boxPos[id] = { x: 0, y: 0 };

  box.addEventListener("mousedown", (e: MouseEvent) => {
    if (activeDragBox && activeDragBox !== box) {
      activeDragBox.classList.remove("dragging");
    }
    activeDragBox = box;
    activeDragBoxId = id;
    lastDragX = e.clientX;
    lastDragY = e.clientY;
    box.classList.add("dragging");
  });
});

document.addEventListener("mousemove", (e: MouseEvent) => {
  if (!activeDragBox || !activeDragBoxId) return;
  boxPos[activeDragBoxId].x += e.clientX - lastDragX;
  boxPos[activeDragBoxId].y += e.clientY - lastDragY;
  lastDragX = e.clientX;
  lastDragY = e.clientY;
  activeDragBox.style.left = boxPos[activeDragBoxId].x + "px";
  activeDragBox.style.top = boxPos[activeDragBoxId].y + "px";
  lastAction.textContent = `Drag box ${activeDragBoxId}`;
});

document.addEventListener("mouseup", () => {
  if (activeDragBox) {
    activeDragBox.classList.remove("dragging");
  }
  activeDragBox = null;
  activeDragBoxId = null;
});

backButton.addEventListener("click", () => navigateTo("home"));

document.addEventListener("beamng:trigger", (event: any) => {
  const { id, action } = event.detail;
  lastAction.textContent = `Trigger: ${id} ${action}`;
});

document.addEventListener("beamng:trigger:click", (event: any) => {
  if (event.detail.id === "acMax") {
    lastAction.textContent = "Trigger: acMax clicked!";
    callVehicleLua("playSound", {});
  }
});

window.setup = function (config) {
  window.initScreenInput({ enableHover: true });
};

window.updateData = function () {
  const d = vehicleData;
  document.getElementById("data-rpm")!.textContent = Math.round(d.electrics!.rpm as number) + " rpm";
  document.getElementById("data-gear")!.textContent = String(d.electrics!.gear);
  document.getElementById("data-wheelspeed")!.textContent = ((d.electrics!.wheelspeed as number) * 3.6).toFixed(1) + " km/h";
  document.getElementById("data-torque")!.textContent = (d.powertrain!.mainEngine.outputTorque1 as number).toFixed(1) + " Nm";
  document.getElementById("data-load")!.textContent = ((d.powertrain!.mainEngine.instantEngineLoad as number) * 100).toFixed(0) + "%";
  document.getElementById("data-gearindex")!.textContent = String(d.powertrain!.gearbox.gearIndex);
  document.getElementById("data-power")!.textContent = (d.customModules!.combustionEngineData.currentPower as number).toFixed(1) + " hp";
  document.getElementById("data-ctorque")!.textContent = (d.customModules!.combustionEngineData.currentTorque as number).toFixed(1) + " Nm";
};

window.updateMode = function (_data) {};
