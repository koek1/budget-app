const express = require('express');
const ExcelJS = require('exceljs');
const auth = require('../middleware/auth');
const Transaction = require('../models/Transaction');
const router = express.Router();

// Generate Excel report
router.post('/excel', auth, async (req, res) => {
  try {
    const { startDate, endDate, reportType } = req.body;
    
    // Validate dates
    if (!startDate || !endDate) {
      return res.status(400).json({ message: 'Start date and end date are required' });
    }

    const start = new Date(startDate);
    const end = new Date(endDate);
    end.setHours(23, 59, 59, 999); // Include entire end date

    // Fetch transactions
    let transactions = await Transaction.find({ userId: req.user._id });
    
    // Filter by date range
    transactions = transactions.filter(t => {
      const tDate = new Date(t.date);
      return tDate >= start && tDate <= end;
    });
    
    // Filter by type if specified
    if (reportType && reportType !== 'all') {
      transactions = transactions.filter(t => t.type === reportType);
    }
    
    // Sort by date ascending
    transactions.sort((a, b) => new Date(a.date) - new Date(b.date));

    // Create workbook
    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'Budget App';
    workbook.created = new Date();

    // Add worksheet
    const worksheet = workbook.addWorksheet('Financial Report');

    // Define columns
    worksheet.columns = [
      { header: 'Date', key: 'date', width: 15 },
      { header: 'Type', key: 'type', width: 10 },
      { header: 'Category', key: 'category', width: 20 },
      { header: 'Description', key: 'description', width: 30 },
      { header: 'Amount', key: 'amount', width: 15 },
    ];

    // Add data rows
    transactions.forEach(transaction => {
      worksheet.addRow({
        date: transaction.date.toISOString().split('T')[0],
        type: transaction.type.charAt(0).toUpperCase() + transaction.type.slice(1),
        category: transaction.category,
        description: transaction.description || '',
        amount: transaction.amount
      });
    });

    // Add summary section
    worksheet.addRow([]); // Empty row
    
    const incomeTotal = transactions
      .filter(t => t.type === 'income')
      .reduce((sum, t) => sum + t.amount, 0);
    
    const expenseTotal = transactions
      .filter(t => t.type === 'expense')
      .reduce((sum, t) => sum + t.amount, 0);
    
    const netTotal = incomeTotal - expenseTotal;

    worksheet.addRow(['SUMMARY', '', '', '', '']);
    worksheet.addRow(['Total Income', '', '', '', incomeTotal]);
    worksheet.addRow(['Total Expenses', '', '', '', expenseTotal]);
    worksheet.addRow(['Net Total', '', '', '', netTotal]);

    // Style the header row
    worksheet.getRow(1).font = { bold: true };
    worksheet.getRow(1).fill = {
      type: 'pattern',
      pattern: 'solid',
      fgColor: { argb: 'FFE6E6FA' }
    };

    // Style summary rows
    for (let i = worksheet.rowCount - 4; i <= worksheet.rowCount; i++) {
      worksheet.getRow(i).font = { bold: true };
    }

    // Style net total row
    worksheet.getRow(worksheet.rowCount).fill = {
      type: 'pattern',
      pattern: 'solid',
      fgColor: { argb: 'FFF0F8FF' }
    };

    // Set response headers for file download
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename=budget-report-${Date.now()}.xlsx`);

    // Write to response
    await workbook.xlsx.write(res);
    res.end();

  } catch (error) {
    console.error('Export error:', error);
    res.status(500).json({ message: 'Error generating report' });
  }
});

// Get report summary (for preview)
router.get('/summary', auth, async (req, res) => {
  try {
    const { startDate, endDate, reportType } = req.query;
    
    const start = new Date(startDate);
    const end = new Date(endDate);
    end.setHours(23, 59, 59, 999);

    // Fetch transactions
    let transactions = await Transaction.find({ userId: req.user._id });
    
    // Filter by date range
    transactions = transactions.filter(t => {
      const tDate = new Date(t.date);
      return tDate >= start && tDate <= end;
    });
    
    // Filter by type if specified
    if (reportType && reportType !== 'all') {
      transactions = transactions.filter(t => t.type === reportType);
    }
    
    // Sort by date ascending
    transactions.sort((a, b) => new Date(a.date) - new Date(b.date));

    // Calculate daily totals for income
    const dailyIncome = {};
    transactions
      .filter(t => t.type === 'income')
      .forEach(t => {
        const dateStr = t.date.toISOString().split('T')[0];
        dailyIncome[dateStr] = (dailyIncome[dateStr] || 0) + t.amount;
      });

    const summary = {
      totalTransactions: transactions.length,
      totalIncome: transactions.filter(t => t.type === 'income').reduce((sum, t) => sum + t.amount, 0),
      totalExpenses: transactions.filter(t => t.type === 'expense').reduce((sum, t) => sum + t.amount, 0),
      netTotal: 0,
      dailyIncome: Object.entries(dailyIncome).map(([date, amount]) => ({ date, amount })),
      transactions: transactions.slice(0, 10) // First 10 for preview
    };
    
    summary.netTotal = summary.totalIncome - summary.totalExpenses;

    res.json(summary);
  } catch (error) {
    console.error('Summary error:', error);
    res.status(500).json({ message: 'Error generating summary' });
  }
});

module.exports = router;