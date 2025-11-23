const fs = require('fs').promises;
const path = require('path');

const DATA_DIR = path.join(__dirname, '../data');

// Ensure data directory exists
async function ensureDataDir() {
  try {
    await fs.mkdir(DATA_DIR, { recursive: true });
  } catch (error) {
    // Directory already exists or other error
  }
}

// Initialize on module load
ensureDataDir();

class FileStorage {
  constructor(filename) {
    this.filepath = path.join(DATA_DIR, `${filename}.json`);
  }

  async read() {
    try {
      await ensureDataDir();
      const data = await fs.readFile(this.filepath, 'utf8');
      return JSON.parse(data);
    } catch (error) {
      // File doesn't exist, return empty array/object
      return [];
    }
  }

  async write(data) {
    await ensureDataDir();
    await fs.writeFile(this.filepath, JSON.stringify(data, null, 2), 'utf8');
  }

  async findById(id) {
    const data = await this.read();
    return Array.isArray(data) ? data.find(item => item._id === id) : null;
  }

  async findOne(query) {
    const data = await this.read();
    if (!Array.isArray(data)) return null;
    
    return data.find(item => {
      return Object.keys(query).every(key => {
        if (key === '_id') {
          return item._id === query[key];
        }
        return item[key] === query[key];
      });
    });
  }

  async find(query = {}) {
    const data = await this.read();
    if (!Array.isArray(data)) return [];
    
    if (Object.keys(query).length === 0) {
      return data;
    }

    return data.filter(item => {
      return Object.keys(query).every(key => {
        if (key === '_id') {
          return item._id === query[key];
        }
        if (key === 'userId') {
          return item.userId === query[key];
        }
        if (key === 'date' && query[key].$gte && query[key].$lte) {
          const itemDate = new Date(item.date);
          return itemDate >= query[key].$gte && itemDate <= query[key].$lte;
        }
        return item[key] === query[key];
      });
    });
  }

  async create(item) {
    const data = await this.read();
    if (!Array.isArray(data)) {
      await this.write([]);
      return this.create(item);
    }
    
    const newItem = {
      _id: this.generateId(),
      ...item,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    
    data.push(newItem);
    await this.write(data);
    return newItem;
  }

  async update(id, updates) {
    const data = await this.read();
    if (!Array.isArray(data)) return null;
    
    const index = data.findIndex(item => item._id === id);
    if (index === -1) return null;
    
    data[index] = {
      ...data[index],
      ...updates,
      updatedAt: new Date().toISOString(),
    };
    
    await this.write(data);
    return data[index];
  }

  async delete(id) {
    const data = await this.read();
    if (!Array.isArray(data)) return null;
    
    const index = data.findIndex(item => item._id === id);
    if (index === -1) return null;
    
    const deleted = data.splice(index, 1)[0];
    await this.write(data);
    return deleted;
  }

  async findOneAndDelete(query) {
    const data = await this.read();
    if (!Array.isArray(data)) return null;
    
    const index = data.findIndex(item => {
      return Object.keys(query).every(key => {
        if (key === '_id') {
          return item._id === query[key];
        }
        return item[key] === query[key];
      });
    });
    
    if (index === -1) return null;
    
    const deleted = data.splice(index, 1)[0];
    await this.write(data);
    return deleted;
  }

  generateId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2);
  }
}

module.exports = FileStorage;

