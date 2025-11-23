const FileStorage = require('../storage/fileStorage');
const bcrypt = require('bcryptjs');

const userStorage = new FileStorage('users');

class User {
  constructor(data) {
    this._id = data._id;
    this.name = data.name;
    this.email = data.email;
    this.password = data.password;
    this.currency = data.currency || 'R';
    this.monthlyBudget = data.monthlyBudget || 0;
    this.createdAt = data.createdAt;
    this.updatedAt = data.updatedAt;
  }

  static async findOne(query) {
    const userData = await userStorage.findOne(query);
    return userData ? new User(userData) : null;
  }

  static async findById(id) {
    const userData = await userStorage.findById(id);
    return userData ? new User(userData) : null;
  }

  static async create(data) {
    // Hash password before saving
    const hashedPassword = await bcrypt.hash(data.password, 12);
    
    const userData = await userStorage.create({
      ...data,
      password: hashedPassword,
      email: data.email.toLowerCase(),
    });
    
    return new User(userData);
  }

  async correctPassword(candidatePassword) {
    return await bcrypt.compare(candidatePassword, this.password);
  }

  async save() {
    const updates = {
      name: this.name,
      email: this.email,
      password: this.password,
      currency: this.currency,
      monthlyBudget: this.monthlyBudget,
    };
    
    const updated = await userStorage.update(this._id, updates);
    if (updated) {
      Object.assign(this, updated);
    }
    return this;
  }

  toJSON() {
    const obj = { ...this };
    delete obj.password;
    return obj;
  }
}

module.exports = User;