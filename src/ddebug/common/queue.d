module ddebug.common.queue;

import core.sync.condition;
import core.sync.mutex;

class BlockingQueue(T) {

	private Mutex _mutex;
	private Condition _condition;

	this() {
		_mutex = new Mutex();
		_condition = new Condition(_mutex);
	}

	~this() {
		// TODO: destroy mutex?
	}

	void put(T item) {
	}

	bool get(ref T value, int timeoutMillis) {
		return false;
	}
}
