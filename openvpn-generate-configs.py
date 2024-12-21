################ Bus

import enum

class EventType(enum.Enum):
    COMMAND = 1
    DATA = 2

class Event:

    def __init__(self, sender: "BusClient", type: EventType, **kwargs):
        self.sender = sender.id()
        self.type = type
        self.args = kwargs

    def __str__(self):
        return f"{self.type}({self.args}) from {self.sender}"

    def __repr__(self):
        return f"Event[sender={self.sender!r}, type={self.type!r}, args={self.args!r}]"

class BusClient:

    def id(self) -> str:
        raise NotImplementedError

    def on_event(self, event: Event):
        raise NotImplementedError

class Bus:

    def __init__(self):
        self.listeners = []

    def add_listener(self, listener: BusClient):
        self.listeners.append(listener)

    def send(self, event: Event):
        for listener in self.listeners:
            if listener.id() != event.sender:
                listener.on_event(event)


################ Repo

class FileRepo(BusClient):

    def __init__(self, bus: Bus):
        self.data = {}
        self.bus = bus
        bus.add_listener(self)

    def id(self) -> str:
        return "FileRepo"

    def on_event(self, event: Event):
        log.debug(f"FileRepo < {event}")
        if event.type == EventType.COMMAND:
            name = event.args["name"]
            del event.args["name"]
            if name == "generate":
                self.generate(**event.args)

        if event.type == EventType.DATA:
            self._on_data(**event.args)

    def _on_data(self, id, val):
        self.set_data(id, val, notify=False)

    def run(self):
        self.set_data("ca.cn", "MyCA")
        self.set_data("ca.valid", 3653)
        self.set_data("client.count", 1)
        self.set_data("client.valid", 3653)
        self.set_data("server.host", "127.0.0.1")

    def set_data(self, id, val, notify=True):
        self.data[id] = val
        if notify:
            self.bus.send(Event(self, EventType.DATA, id=id, val=val))

    def generate(self):
        log.debug(f"generate from data {self.data}")
        pass


################ Gui

class Lang:

    def str(self, text: str) -> str:
        return text

import tkinter as tk
import tkinter.ttk as ttk

class Comp:

    def __init__(self, constr):
        self.constr = constr

    def new(self, *args, **kwargs):
        self.instance = self.constr(*args, **kwargs)
        return self

    def insert_at_0(self, *args, **kwargs):
        self.instance.insert(0, *args, **kwargs)
        return self

    def pack(self, *args, **kwargs):
        self.instance.pack(*args, **kwargs)
        return self.instance

class TwoColFrame:

    def __init__(self, gui, parent):
        self.gui = gui
        self.comp = Comp(tk.Frame).new(parent).pack()
        self.left = Comp(tk.Frame).new(self.comp).pack(side=tk.LEFT)
        self.right = Comp(tk.Frame).new(self.comp).pack(side=tk.RIGHT)

    def add_entry(self, id, label, var):
        Comp(tk.Label).new(self.left, text=self.gui._i(label)).pack()
        Comp(tk.Entry).new(self.right, textvariable=var).pack()
        self.gui.vars[id] = var
        var.trace_add("write", lambda *args: self.gui._on_gui_update(id, var))
        return self

class Notebook:

    def __init__(self, gui, parent):
        self.gui = gui
        self.comp = Comp(ttk.Notebook).new(parent).pack()

    def add_tab(self, label, tab):
        self.comp.add(tab(self.comp).comp, text=self.gui._i(label))
        return self

class CATkGui(BusClient):

    def __init__(self, lang: Lang, bus: Bus):
        self.vars = {}
        self.lang = lang
        self.bus = bus
        bus.add_listener(self)
        self._init_window()

    def _init_window(self):
        self.tk = tk.Tk()
        self.tk.geometry("200x150")
        self.tk.title(self._i("OpenVPN config generator"))

        frame = Comp(tk.Frame).new(self.tk).pack()

        Notebook(self, frame) \
        \
        .add_tab("CA", lambda comp: TwoColFrame(self, comp) \
        .add_entry("ca.cn", "Common name", tk.StringVar()) \
        .add_entry("ca.valid", "Valid in years", tk.IntVar())) \
        \
        .add_tab("Clients", lambda comp: TwoColFrame(self, comp) \
        .add_entry("client.count", "Number of clients", tk.IntVar()) \
        .add_entry("client.valid", "Valid in years", tk.IntVar())) \
        \
        .add_tab("Settings", lambda comp: TwoColFrame(self, comp) \
        .add_entry("server.host", "Server host", tk.StringVar()))

        self.generate = Comp(tk.Button).new(frame, text=self._i("Generate"),
                                         command=lambda: self.on_generate()).pack()

    def _i(self, text: str) -> str:
        return self.lang.str(text)

    def on_generate(self):
        self.bus.send(Event(self, EventType.COMMAND, name="generate"))

    def id(self) -> str:
        return "CATkGui"

    def on_event(self, event: Event):
        log.debug(f"CATkGui < {event}")
        if event.type == EventType.DATA:
            self._on_data(**event.args)

    def _on_data(self, id, val):
        var = self.vars.get(id)
        if var is not None:
            cbname = var.trace_info()[0][1]
            var.trace_remove("write", cbname)
            var.set(val)
            var.trace_add("write", lambda *args: self._on_gui_update(id, var))

    def _on_gui_update(self, id, var):
        self.bus.send(Event(self, EventType.DATA, id=id, val=var.get()))

    def run(self):
        self.tk.mainloop()

################ Main

import logging

log = logging.getLogger(__name__)

def main():
    logging.basicConfig(level=logging.DEBUG)
    bus = Bus()
    repo = FileRepo(bus)
    ui = CATkGui(Lang(), bus)
    repo.run()
    ui.run()

if __name__ == "__main__":
    main()
