const FileStorage = require('../storage/fileStorage');

const transactionStorage = new FileStorage('transactions');

class Transaction {
  constructor(data) {
    this._id = data._id;
    this.userId = data.userId;
    this.amount = data.amount;
    this.type = data.type;
    this.category = data.category;
    this.description = data.description || '';
    this.date = data.date ? new Date(data.date) : new Date();
    this.isSynced = data.isSynced !== undefined ? data.isSynced : true;
    this.createdAt = data.createdAt;
    this.updatedAt = data.updatedAt;
  }

  static async find(query) {
    const transactions = await transactionStorage.find(query);
    return transactions.map(t => new Transaction(t));
  }

  static async findOne(query) {
    const transactionData = await transactionStorage.findOne(query);
    return transactionData ? new Transaction(transactionData) : null;
  }

  static async findOneAndDelete(query) {
    const transactionData = await transactionStorage.findOneAndDelete(query);
    return transactionData ? new Transaction(transactionData) : null;
  }

  async save() {
    if (this._id) {
      // Update existing
      const updates = {
        userId: this.userId,
        amount: this.amount,
        type: this.type,
        category: this.category,
        description: this.description,
        date: this.date,
        isSynced: this.isSynced,
      };
      const updated = await transactionStorage.update(this._id, updates);
      if (updated) {
        Object.assign(this, updated);
      }
      return this;
    } else {
      // Create new
      const newTransaction = await transactionStorage.create({
        userId: this.userId,
        amount: this.amount,
        type: this.type,
        category: this.category,
        description: this.description,
        date: this.date,
        isSynced: this.isSynced,
      });
      Object.assign(this, newTransaction);
      return this;
    }
  }
}

module.exports = Transaction;