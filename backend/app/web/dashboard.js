const byId = (id) => document.getElementById(id);
let token = sessionStorage.getItem("ata-session");
let selectedJob;
let letter;
let busy = false;

const labels = {
  auto: "OmniRoute del servidor", codex: "Codex", claude: "Claude Code",
  antigravity: "Antigravity", omniroute: "OmniRoute en tu equipo",
  api: "API en tu equipo", custom: "Conector personalizado", api_key: "Clave API directa",
};
const local = (provider) => provider !== "auto" && provider !== "api_key";

async function api(path, method = "GET", body) {
  const response = await fetch(path, {
    method, cache: "no-store",
    headers: { ...(token && { Authorization: "Bearer " + token }),
      ...(body && { "Content-Type": "application/json" }) },
    body: body && JSON.stringify(body),
  });
  if (response.status === 204) return null;
  const data = await response.json();
  if (!response.ok) {
    if (response.status === 401 && token) logout();
    throw Error(typeof data.detail === "string" ? data.detail : "Comprueba los datos ingresados.");
  }
  return data;
}

async function run(action) {
  if (busy) return;
  busy = true;
  byId("status").textContent = "";
  try { await action(); }
  catch (error) { byId("status").textContent = error.message; }
  finally { busy = false; }
}

function logout() {
  token = null;
  sessionStorage.removeItem("ata-session");
  selectedJob = letter = undefined;
  for (const id of ["jobs", "applications", "answer", "code", "command", "job-context", "who"]) {
    byId(id).textContent = "";
  }
  byId("key").value = "";
  byId("model").value = "";
  byId("profile").reset();
  byId("question").reset();
  byId("workspace").hidden = true;
  byId("account").hidden = false;
}

function providerView(provider, state) {
  byId("pairing").hidden = true;
  byId("code").textContent = "";
  byId("pair").hidden = byId("revoke").hidden = !local(provider);
  byId("key-label").hidden = byId("model-label").hidden = provider !== "api_key";
  byId("provider-status").textContent = local(provider)
    ? (state ? "Conector en línea" : "Conector sin conexión")
    : (provider === "api_key" ? "La clave se usa en esta sesión." : "Usa la configuración del servidor.");
}

let paired = {};
async function refreshProviders() {
  const data = await api("/ai/connectors");
  paired = data.paired;
  const select = byId("provider");
  select.replaceChildren(...["auto", ...data.providers, "api_key"].map(
    (id) => new Option(labels[id], id),
  ));
  select.value = data.selected;
  providerView(data.selected, paired[data.selected]);
}

async function showAccount() {
  const data = await api("/me");
  byId("who").textContent = data.user.name || data.user.email;
  const profile = byId("profile");
  profile.elements.role.value = data.preferences.role || "";
  profile.elements.skills.value = Array.isArray(data.preferences.skills)
    ? data.preferences.skills.join(", ") : "";
  byId("workspace").hidden = false;
  byId("account").hidden = true;
  await refreshProviders();
  await showApplications();
}

function button(label, handler) {
  const element = document.createElement("button");
  element.type = "button";
  element.textContent = label;
  element.onclick = () => run(handler);
  return element;
}

function jobCard(job, controls) {
  const card = document.createElement("article");
  const title = document.createElement("strong");
  title.textContent = job.title;
  const company = document.createElement("p");
  company.textContent = [job.company, job.location, job.source].filter(Boolean).join(" · ");
  const actions = document.createElement("div");
  actions.className = "actions";
  try {
    const url = new URL(job.url);
    if (["http:", "https:"].includes(url.protocol)) {
      const link = document.createElement("a");
      link.href = url.href;
      link.target = "_blank";
      link.rel = "noopener noreferrer";
      link.textContent = "Abrir oferta";
      actions.append(link);
    }
  } catch { /* Optional link. */ }
  actions.append(...controls);
  card.append(title, company, actions);
  return card;
}

function selectJob(job) {
  selectedJob = job;
  letter = undefined;
  byId("job-context").textContent = "Oferta seleccionada: " + job.title;
  byId("answer").textContent = "";
}

async function ask(path, body) {
  byId("answer").textContent = "Esperando al proveedor…";
  const provider = byId("provider").value;
  const extras = provider === "api_key"
    ? { model: byId("model").value, api_key: byId("key").value } : {};
  try {
    let data = await api(path, "POST", { ...body, provider, ...extras });
    const until = Date.now() + 180000;
    const task = data.task_id;
    while (task && !data.reply && data.state !== "failed" && Date.now() < until) {
      await new Promise((resolve) => setTimeout(resolve, 2500));
      data = await api("/ai/tasks/" + encodeURIComponent(task));
    }
    if (!data.reply) throw Error(data.detail || "El proveedor tardó demasiado.");
    byId("answer").textContent = data.reply;
    return data.reply;
  } catch (error) {
    byId("answer").textContent = "";
    throw error;
  }
}

async function save(job, draft = "") {
  await api("/applications", "POST", {
    job_id: job.id, title: job.title, company: job.company, source: job.source,
    url: job.url, country: job.country, status: "liked", method: "none", cover_letter: draft,
  });
  await showApplications();
  byId("status").textContent = "Oferta guardada.";
}

async function showApplications() {
  const { applications } = await api("/applications");
  byId("applications").replaceChildren(...applications.filter((item) => item.status !== "skipped").map((item) => {
    const confirmed = item.status === "applied" && item.method === "manual_confirmation";
    const controls = [];
    if (item.cover_letter) controls.push(button("Ver carta", () => {
      byId("answer").textContent = item.cover_letter;
      byId("answer").scrollIntoView();
    }));
    if (!confirmed) controls.push(button("Confirmar envío", async () => {
      if (!window.confirm("¿Ya enviaste el formulario al empleador?")) return;
      await api("/applications/" + item.id, "PATCH", { status: "applied", confirmed_submission: true });
      await showApplications();
    }));
    return jobCard({ ...item, location: confirmed ? "Enviada" : "Pendiente" }, controls);
  }));
}

byId("account").onsubmit = (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const data = Object.fromEntries(new FormData(form));
  const action = event.submitter?.value || "login";
  run(async () => {
    const response = await api("/auth/" + action, "POST", data);
    form.reset();
    token = response.token;
    sessionStorage.setItem("ata-session", token);
    await showAccount();
  });
};
byId("logout").onclick = () => { if (!busy) logout(); };
byId("provider").onchange = () => {
  const provider = byId("provider").value;
  providerView(provider, paired[provider]);
};
byId("select-provider").onclick = () => run(async () => {
  await api("/ai/provider", "PUT", { provider: byId("provider").value });
  await refreshProviders();
  byId("status").textContent = "Proveedor guardado en tu cuenta.";
});
byId("pair").onclick = () => run(async () => {
  const provider = byId("provider").value;
  if (provider in paired && !window.confirm("Se sustituirá el código anterior de este proveedor.")) return;
  const data = await api("/ai/connectors", "POST", { provider });
  byId("command").textContent = "python connector.py " + provider + " --server " + location.origin;
  byId("code").textContent = data.token;
  byId("pairing").hidden = false;
});
byId("revoke").onclick = () => run(async () => {
  const provider = byId("provider").value;
  await api("/ai/connectors/" + provider, "DELETE");
  await refreshProviders();
});
byId("profile").onsubmit = (event) => {
  event.preventDefault();
  const fields = new FormData(event.currentTarget);
  run(async () => {
    await api("/me/preferences", "PUT", {
      preferences: { role: fields.get("role").trim(), skills: fields.get("skills").split(",").map(s => s.trim()).filter(Boolean) },
    });
    byId("status").textContent = "Perfil guardado.";
  });
};
byId("search").onsubmit = (event) => {
  event.preventDefault();
  const query = new URLSearchParams(new FormData(event.currentTarget));
  run(async () => {
    const { jobs } = await api("/jobs/search?" + query);
    byId("jobs").replaceChildren(...jobs.map((job) => jobCard(job, [
      button("Seleccionar para Ana", () => { selectJob(job); byId("question").scrollIntoView(); }),
      button("Preparar carta", async () => {
        selectJob(job);
        byId("question").scrollIntoView();
        letter = await ask("/ai/cover-letter", { job: { id: job.id } });
      }),
      button("Guardar", () => save(job, selectedJob?.id === job.id ? letter : "")),
    ])));
    if (!jobs.length) byId("jobs").textContent = "No se encontraron ofertas.";
  });
};
byId("question").onsubmit = (event) => {
  event.preventDefault();
  const question = new FormData(event.currentTarget).get("question");
  run(() => ask("/ai/chat", {
    messages: [{ role: "user", content: question }], job_id: selectedJob?.id,
  }));
};
byId("refresh").onclick = () => run(showApplications);
if (token) run(showAccount);
